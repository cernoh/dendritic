--!nonstrict
-- Telemetry service for the museum bar.
--
-- One runtime owns every live feed the six bar entries need, so six widgets do
-- not each spawn a compositor stream or a ddcutil probe. Values are published
-- on the plugin's in-memory state channel; the entries only render.
--
-- State keys (plain values, documented for the drawer as well):
--   tags   { all_tags = { { monitor, tags = { { index, is_active,
--            is_urgent, client_count, layout } } } } }  (mmsg all-tags)
--   active { id, title, appid, monitor } | nil          (mmsg focusing-client)
--   stats  { ramUsedMb, cpuUsage, gpuUsage, cpuTempC }  (noctalia.systemStats)
--   drives { tempC, degradedPct }                       (/run/…/raw.json, schema 2)
--   media  { status, title } | nil                      (playerctl)
--   audio  { volume, muted, brightness }                 (wpctl, sysfs/ddcutil)
--   unread number                                        (notification history)
--
-- EXPLICIT EXCEPTION to PLAN 3.3: the machine and thermal numbers come from
-- noctalia.systemStats()/the drive-health collector, not by shelling out. The
-- tray has no plugin API at all (no MPRIS, tray, notification count, volume or
-- brightness surface at plugin_api 34), so those four use the same sources the
-- shell's own widgets use. Reading the shell's notification history is the only
-- stable count it exposes.

local mango = require("./lib/mango.luau")

local json = noctalia.json

local lastPublished = {}

local function publish(key, value)
  local encoded = json.encode(value)
  if encoded ~= nil and lastPublished[key] == encoded then
    return
  end
  lastPublished[key] = encoded
  noctalia.state.set(key, value)
end

-- ── compositor ─────────────────────────────────────────────────────────────

local function startCompositor()
  mango.watch({ "watch", "all-tags" }, function(data)
    publish("tags", data)
  end)
  mango.watch({ "watch", "focusing-client" }, function(data)
    if data == nil or data.id == nil then
      publish("active", nil)
    else
      publish("active", {
        id = data.id,
        title = data.title,
        appid = data.appid,
        monitor = data.monitor,
      })
    end
  end)

  -- A watch only reports changes; seed the current values once.
  mango.get({ "get", "all-tags" }, function(data)
    if data ~= nil then
      publish("tags", data)
    end
  end)
  mango.get({ "get", "focusing-client" }, function(data)
    if data ~= nil and data.id ~= nil then
      publish("active", {
        id = data.id,
        title = data.title,
        appid = data.appid,
        monitor = data.monitor,
      })
    end
  end)
end

-- ── system monitor (PLAN 3.3: no shelling out) ─────────────────────────────

local function pollStats()
  local snapshot = noctalia.systemStats()
  if snapshot == nil then
    publish("stats", nil)
    return
  end
  publish("stats", {
    ramUsedMb = snapshot.ram and snapshot.ram.usedMb or nil,
    cpuUsage = snapshot.cpu and snapshot.cpu.usagePercent or nil,
    gpuUsage = snapshot.gpu and snapshot.gpu.usagePercent or nil,
    cpuTempC = snapshot.cpu and snapshot.cpu.tempC or nil,
  })
end

-- ── drive health (read, never collect — system/disk-health owns the timer) ─

local drivePath = noctalia.getConfig("drive_raw_path") or "/run/noctalia-drive-health/raw.json"

local function pollDrives()
  local raw = noctalia.readFile(drivePath)
  if raw == nil then
    publish("drives", nil)
    return
  end
  local data = json.decode(raw)
  if data == nil or data.schema ~= 2 or data.smart == nil then
    publish("drives", nil)
    return
  end

  local temp = nil
  local degraded = 0
  for _, drive in ipairs(data.smart) do
    local payload = drive.payload or {}
    local current = payload.temperature and payload.temperature.current
    if current ~= nil and (temp == nil or current > temp) then
      temp = current
    end

    -- NVMe reports endurance directly; SATA reports spare headroom. The
    -- gauge shows the worst drive, per DESIGN §9.3.
    local used = nil
    if payload.endurance_used and payload.endurance_used.current_percent ~= nil then
      used = payload.endurance_used.current_percent
    elseif payload.spare_available and payload.spare_available.current_percent ~= nil then
      used = 100 - payload.spare_available.current_percent
    end
    if used ~= nil and used > degraded then
      degraded = used
    end
  end

  publish("drives", { tempC = temp, degradedPct = degraded })
end

-- ── tray feeds: MPRIS, volume, brightness, unread count ───────────────────

local mediaPending = false
local function pollMedia()
  if mediaPending or not noctalia.commandExists("playerctl") then
    return
  end
  mediaPending = true
  noctalia.runAsync({ "playerctl", "metadata", "--format", "{{status}}|{{title}}" }, function(result)
    mediaPending = false
    if result == nil or result.exitCode ~= 0 then
      publish("media", nil)
      return
    end
    local line = noctalia.string.trim(result.stdout or "")
    local status, title = string.match(line, "^([^|]*)|(.*)$")
    if status == nil or status == "" then
      publish("media", nil)
      return
    end
    publish("media", { status = status, title = title or "" })
  end)
end

local volumePending = false
local function pollVolume()
  if volumePending or not noctalia.commandExists("wpctl") then
    return
  end
  volumePending = true
  noctalia.runAsync({ "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(result)
    volumePending = false
    if result == nil or result.exitCode ~= 0 then
      return
    end
    local value, rest = string.match(result.stdout or "", "Volume:%s*([%d%.]+)(.*)")
    if value == nil then
      return
    end
    local audio = noctalia.state.get("audio") or {}
    audio.volume = math.floor(tonumber(value) * 100 + 0.5)
    audio.muted = string.find(rest or "", "%[MUTED%]", 1, false) ~= nil
    publish("audio", audio)
  end)
end

-- The kernel backlight covers internal panels (ASAHI); an external monitor
-- needs a DDC/CI probe (NIXPC). That probe costs ~0.9 s, so it is the one feed
-- with a deliberately slow cadence.
local brightnessPending = false
local function readBrightness()
  if brightnessPending then
    return
  end

  local devices = noctalia.listDir("/sys/class/backlight")
  if devices ~= nil and #devices > 0 then
    local base = "/sys/class/backlight/" .. devices[1]
    local raw = noctalia.readFile(base .. "/brightness")
    local max = noctalia.readFile(base .. "/max_brightness")
    if raw ~= nil and max ~= nil then
      local value, ceiling = tonumber(noctalia.string.trim(raw)), tonumber(noctalia.string.trim(max))
      if value ~= nil and ceiling ~= nil and ceiling > 0 then
        local audio = noctalia.state.get("audio") or {}
        audio.brightness = math.floor(value / ceiling * 100 + 0.5)
        publish("audio", audio)
      end
    end
    return
  end

  if not noctalia.commandExists("ddcutil") then
    return
  end
  brightnessPending = true
  noctalia.runAsync({ "ddcutil", "getvcp", "10" }, function(result)
    brightnessPending = false
    if result == nil or result.exitCode ~= 0 then
      return
    end
    local current = tonumber(string.match(result.stdout or "", "current value%s*=%s*(%d+)"))
    local ceiling = tonumber(string.match(result.stdout or "", "max value%s*=%s*(%d+)"))
    if current == nil or ceiling == nil or ceiling == 0 then
      return
    end
    local audio = noctalia.state.get("audio") or {}
    audio.brightness = math.floor(current / ceiling * 100 + 0.5)
    publish("audio", audio)
  end)
end

local function notificationHistoryPath()
  local stateHome = noctalia.getenv("NOCTALIA_STATE_HOME")
  if stateHome ~= nil and stateHome ~= "" then
    return stateHome .. "/notification_history.json"
  end
  return noctalia.expandPath("~/.local/state/noctalia/notification_history.json")
end

local function pollUnread()
  local raw = noctalia.readFile(notificationHistoryPath())
  if raw == nil then
    return
  end
  local data = json.decode(raw)
  if data == nil or data.entries == nil then
    return
  end
  local unread = 0
  for _, entry in ipairs(data.entries) do
    if entry.seen ~= true then
      unread = unread + 1
    end
  end
  publish("unread", unread)
end

-- ── cadence ───────────────────────────────────────────────────────────────

local tick = 0

local function every(period, fn)
  if tick % period == 0 then
    fn()
  end
end

startCompositor()
noctalia.setUpdateInterval(1000)

function update()
  tick = tick + 1
  every(2, pollStats)
  every(2, pollMedia)
  every(2, pollVolume)
  every(6, pollUnread)
  every(30, pollDrives)
  every(40, readBrightness)
end

-- Seed the cheap values immediately rather than waiting for a tick.
pollStats()
pollMedia()
pollVolume()
pollUnread()
pollDrives()
