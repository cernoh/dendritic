--!nonstrict
-- Ambient-light auto brightness for the internal panel and the keyboard
-- backlight. ASAHI only: it is the one host in this flake with an ambient
-- light sensor (the `aop-sensors-als` IIO device). On a host without one the
-- service logs the fact and does nothing.
--
-- Policy. The target is recomputed on every poll, but it is applied only on
-- two triggers:
--   - the hourly refresh, or
--   - a dramatic shift in ambient light, confirmed by a second sample so that
--     a passing shadow or a hand over the sensor does not fire.
-- A trigger that does not move the target by MIN_APPLY_PCT is a no-op, so a
-- hand-set brightness stays where the user put it until the light changes.
--
-- Brightness goes through Noctalia's own IPC commands rather than the sysfs
-- files. That keeps the shell's brightness service in step (it watches the
-- backlight sysfs, and UPower reports the keyboard backlight), and the values
-- survive a shell restart. The shell pops a brightness OSD for every change,
-- including these, so the sets run inside osd-disable / osd-enable and only
-- the change lands; a concurrent volume OSD would be cut short. When OSDs
-- are off in config there is nothing to suppress and the guard is skipped.
--
-- The constants below are the calibration knob. This file is linked live out
-- of the dendritic checkout, so an edit reloads the service with no rebuild.

-- How often the sensor is read. The decision to apply is separate.
local POLL_MS = 30000
-- Re-apply interval while the light is stable.
local REFRESH_MS = 60 * 60 * 1000
-- Ratio between two light levels that counts as a dramatic shift.
local DRAMATIC_RATIO = 2.0
-- Smallest target move worth an IPC call, in display percentage points.
local MIN_APPLY_PCT = 5
-- The internal panel's connector name. External monitors are left alone:
-- ambient light says nothing about a display in a room you did not measure.
local DISPLAY_OUTPUT = "eDP-1"

-- Lux breakpoints with the display and keyboard percentage at each. Values
-- between two breakpoints are interpolated. The keyboard backlight is useful
-- in the dark and invisible in daylight, so it runs the other way.
local LUX = { 0, 5, 20, 50, 150, 400, 1000, 3000, 10000 }
local DISPLAY_PCT = { 12, 18, 28, 40, 55, 70, 85, 95, 100 }
local KEYBOARD_PCT = { 100, 85, 55, 25, 0, 0, 0, 0, 0 }

-- Applied values, or nil until the first apply of this run.
local appliedDisplayPct = nil
local appliedKeyboardPct = nil
-- Lux at the last apply: the reference a shift is measured against.
local baselineLux = nil
-- Most recent sample.
local lastLux = nil
local lastAppliedSec = 0
local reportedMissingSensor = false
-- nil until the CLI has been looked for once.
local cliAvailable = nil

local function interpolate(lux, percentages)
  if lux <= LUX[1] then
    return percentages[1]
  end
  for i = 2, #LUX do
    if lux <= LUX[i] then
      local span = LUX[i] - LUX[i - 1]
      local t = (lux - LUX[i - 1]) / span
      return percentages[i - 1] + t * (percentages[i] - percentages[i - 1])
    end
  end
  return percentages[#LUX]
end

-- Read the ambient light sensor in lux, or nil when there is no sensor or the
-- kernel gives no value. The IIO device index is probe order, so the device is
-- found by name instead of hardcoding iio:deviceN.
local function readLux()
  local root = "/sys/bus/iio/devices"
  local devices = noctalia.listDir(root)
  if devices == nil then
    return nil
  end
  for _, device in ipairs(devices) do
    local dir = root .. "/" .. device
    local name = noctalia.readFile(dir .. "/name")
    if name ~= nil and name:lower():find("als", 1, true) ~= nil then
      local raw = noctalia.readFile(dir .. "/in_illuminance_input")
      local lux = raw ~= nil and tonumber(raw) or nil
      if lux ~= nil then
        return lux
      end
    end
  end
  return nil
end

local function noSensor(message)
  if not reportedMissingSensor then
    reportedMissingSensor = true
    noctalia.log(message)
  end
end

-- One shell line runs the sets in order; the values are computed numbers and
-- fixed ids, so there is nothing to quote.
local function apply(displayPct, keyboardPct)
  local sets = "noctalia msg brightness-set "
    .. DISPLAY_OUTPUT
    .. " "
    .. string.format("%.3f", displayPct / 100)
    .. " && noctalia msg keyboard-backlight-set "
    .. tostring(keyboardPct)
  -- The shell pops a brightness OSD for every change, including these. Wrap
  -- the sets in osd-disable / osd-enable so only the change lands. The
  -- trailing `;` re-enables even if a set fails, so OSDs never stick off.
  -- getSetting needs plugin API 26. Unknown reads fail open: the OSD shows
  -- rather than risk leaving OSDs disabled.
  local command = sets
  if noctalia.getSetting("osd.enabled") == true then
    command = "noctalia msg osd-disable && " .. sets .. "; noctalia msg osd-enable"
  end
  local accepted = noctalia.runAsync(command, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("auto-brightness: apply failed: " .. (result.stderr or ""))
    end
  end)
  if not accepted then
    noctalia.log("auto-brightness: apply was not started")
  end
end

-- Ratio between two light levels, with 0 lux treated as a small positive value
-- so that a dark room against a lit one is a large shift rather than a
-- division by zero.
local function ratio(a, b)
  local low = math.min(a, b)
  local high = math.max(a, b)
  return high / (low > 0 and low or 0.001)
end

function update()
  local lux = readLux()
  if lux == nil then
    noSensor("auto-brightness: no ambient light sensor on this host")
    return
  end
  if cliAvailable == nil then
    cliAvailable = noctalia.commandExists("noctalia")
  end
  if not cliAvailable then
    noSensor("auto-brightness: the noctalia CLI is not on PATH")
    return
  end

  local displayPct = interpolate(lux, DISPLAY_PCT)
  local keyboardPct = math.floor(interpolate(lux, KEYBOARD_PCT) + 0.5)
  local now = os.time()

  -- A dramatic shift needs the previous sample to agree, so the reference is
  -- the last applied level and not the sample before this one: a step change
  -- satisfies it on the second sample, a single spike never does.
  local shifted = baselineLux ~= nil and lastLux ~= nil
    and ratio(lux, baselineLux) >= DRAMATIC_RATIO
    and ratio(lastLux, baselineLux) >= DRAMATIC_RATIO

  local due = (now - lastAppliedSec) >= (REFRESH_MS / 1000)
  local moved = appliedDisplayPct == nil
    or math.abs(displayPct - appliedDisplayPct) >= MIN_APPLY_PCT
    or math.abs(keyboardPct - appliedKeyboardPct) >= MIN_APPLY_PCT

  if (shifted or due) and moved then
    apply(displayPct, keyboardPct)
    noctalia.log(string.format(
      "auto-brightness: %d lux -> display %d%%, keyboard %d%% (%s)",
      math.floor(lux + 0.5), math.floor(displayPct + 0.5), keyboardPct, shifted and "shift" or "refresh"
    ))
    appliedDisplayPct = displayPct
    appliedKeyboardPct = keyboardPct
    lastAppliedSec = now
    baselineLux = lux
  end

  lastLux = lux
end

noctalia.setUpdateInterval(POLL_MS)
