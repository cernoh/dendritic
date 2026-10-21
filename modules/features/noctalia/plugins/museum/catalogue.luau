--!nonstrict
-- The catalogue service: every read and every command the catalogue drawer
-- needs, in one runtime.
--
-- The panel renders; this runtime fetches (module AGENTS.md: "The panel reads;
-- the service fetches"). The drawer's whole record is published on one state
-- key, `drawer`, and the drawer's controls post work back on the plugin's
-- request channel (`request` + `request_rev`), so no subprocess ever starts in
-- a render path:
--
--   published              source                        section
--   maker/medium/origin    /proc/cpuinfo, nvidia-smi,   System · Provenance
--     /substrate/frame       /etc/os-release, /proc/…
--   supplies[]             /sys/class/power_supply      Power · devices
--   profile                powerprofilesctl get         Power · profile
--   audio.sink/source      wpctl get-volume/inspect     Audio
--   audio.apps[]           pactl -f json                Audio · applications
--   wired/addresses        nmcli device status, ip -j   Network
--   networks[]             nmcli device wifi list       Network
--   bt.{powered,…}         bluetoothctl show/devices    Bluetooth
--   media{}                playerctl                    Media
--
-- Every command is a `runAsync` **argument array** (plugin_api 24), gated on
-- `commandExists`: a host without `nmcli` leaves its section honest instead of
-- raising. The feed is compared as JSON and republished only when it changed,
-- so an idle drawer generates no state traffic.
--
-- Commands arrive as requests and are executed here, never in the panel:
--
--   request("profile", { id = "performance" })      powerprofilesctl set
--   request("mute", { slot = "sink" })               wpctl set-mute … toggle
--   request("link", { on = true, name = "enp5s0" })  nmcli device connect
--   request("wifi", { ssid = "…" })                  nmcli device wifi connect
--   request("bluetooth-power", { on = true })         bluetoothctl power
--   request("bluetooth-discoverable", { on = false }) bluetoothctl discoverable
--   request("media", { action = "play-pause" })       playerctl
--   request("refresh")                                re-read now
--
-- tests/driver-catalogue.luau asserts the parsers and the commands.

-- One tick per second, and the poll is split into five stages, so no single
-- callback starts more than a handful of processes. The shell budgets 25 ms of
-- worker CPU per callback, and a process spawn is not free: a full sweep in
-- one callback (fifteen spawns) crossed that budget on the live host. Five
-- stages mean every group is refreshed within five seconds of the last.
local INTERVAL_MS = 1000

local META_FORMAT = "{{playerName}}|{{title}}|{{artist}}|{{mpris:length}}|{{position}}"

local feed = {}
local lastPublished = nil
-- `nvidia-smi` is tried three times and then left alone: on NIXPC it segfaults,
-- and a failing probe must not be respawned every sweep for the plugin's life.
local gpuAttempts = 0
local lastRequestRev = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function trim(text)
  if text == nil then
    return nil
  end
  return (string.gsub(tostring(text), "^%s*(.-)%s*$", "%1"))
end

local function firstLine(text)
  if text == nil then
    return nil
  end
  return string.match(tostring(text), "^([^\n]*)")
end

local function readTrimmed(path)
  local text = noctalia.readFile(path)
  if text == nil then
    return nil
  end
  return trim(firstLine(text))
end

local function output(result)
  if result == nil or (result.exitCode or 1) ~= 0 then
    return nil
  end
  return result.stdout
end

local function run(argv, onDone)
  if not noctalia.commandExists(argv[1]) then
    return false
  end
  return noctalia.runAsync(argv, function(result)
    if result == nil then
      return
    end
    onDone(result)
  end)
end

-- MPRIS player names are reverse-DNS or a bare binary; the museum names the
-- application. An unknown player falls back to its own name.
local function appFor(player)
  if player == nil then
    return nil
  end
  local known = {
    brave = "Brave",
    ["brave-browser"] = "Brave",
    firefox = "Firefox",
    chromium = "Chromium",
    ["chromium-browser"] = "Chromium",
    spotify = "Spotify",
    mpv = "mpv",
    vlc = "VLC",
    celluloid = "Celluloid",
  }
  return known[string.lower(tostring(player))] or player
end

-- Republish only on a real change: the drawer re-renders on every write.
local function publish()
  local encoded = noctalia.json.encode(feed)
  if encoded ~= nil and encoded == lastPublished then
    return
  end
  lastPublished = encoded
  noctalia.state.set("drawer", feed)
end

-- ---------------------------------------------------------------------------
-- Provenance and power
-- ---------------------------------------------------------------------------

-- A model name needs a working probe; the driver is readable from sysfs even
-- when `nvidia-smi` cannot start (it segfaults on NIXPC today). The fallback
-- names the driver, not a model: it never claims more than the kernel says.
local GPU_DRIVERS = {
  nvidia = "NVIDIA GPU",
  nouveau = "NVIDIA GPU (nouveau)",
  amdgpu = "AMD GPU",
  i915 = "Intel GPU",
  xe = "Intel GPU",
}

local function gpuFromDriver()
  for _, card in ipairs(noctalia.listDir("/sys/class/drm") or {}) do
    if string.match(card, "^card%d+$") then
      local uevent = noctalia.readFile("/sys/class/drm/" .. card .. "/device/uevent")
      local driver = uevent and string.match(uevent, "DRIVER=([%w_%-]+)")
      if driver ~= nil and GPU_DRIVERS[driver] ~= nil then
        return GPU_DRIVERS[driver]
      end
    end
  end
  return nil
end

local function loadProvenance()
  local cpuinfo = noctalia.readFile("/proc/cpuinfo")
  feed.maker = cpuinfo and trim(string.match(cpuinfo, "model name%s*:%s*([^\n]+)")) or nil

  local osRelease = noctalia.readFile("/etc/os-release")
  feed.origin = osRelease and trim(string.match(osRelease, 'PRETTY_NAME="([^"]+)"')) or nil
  feed.substrate = readTrimmed("/proc/sys/kernel/osrelease")
  feed.hostname = readTrimmed("/etc/hostname")
  feed.frame = trim(noctalia.getenv("XDG_CURRENT_DESKTOP"))

  local uptime = noctalia.readFile("/proc/uptime")
  feed.uptime = uptime and tonumber(string.match(uptime, "^(%d+)")) or nil

  if gpuAttempts < 3 then
    gpuAttempts = gpuAttempts + 1
    run({ "nvidia-smi", "--query-gpu=name", "--format=csv,noheader" }, function(result)
      local text = output(result)
      local model = text and trim(firstLine(text))
      feed.gpu = (model ~= nil and model ~= "") and model or gpuFromDriver()
      publish()
    end)
  end
  -- The probe may never answer (missing tool, crashing driver); ask sysfs
  -- immediately rather than leaving the medium blank until a callback that
  -- will not come.
  feed.gpu = feed.gpu or gpuFromDriver()
end

local function loadSupplies()
  local supplies = {}
  for _, entry in ipairs(noctalia.listDir("/sys/class/power_supply") or {}) do
    local base = "/sys/class/power_supply/" .. entry
    local kind = readTrimmed(base .. "/type")
    if kind ~= nil then
      supplies[#supplies + 1] = {
        name = entry,
        kind = kind,
        capacity = tonumber(readTrimmed(base .. "/capacity")),
        status = readTrimmed(base .. "/status"),
      }
    end
  end
  feed.supplies = supplies
end

local function loadPower()
  run({ "powerprofilesctl", "get" }, function(result)
    local text = output(result)
    feed.profile = text and trim(firstLine(text)) or nil
    publish()
  end)
end

-- ---------------------------------------------------------------------------
-- Audio
-- ---------------------------------------------------------------------------

local function loadVolume(slot, target)
  run({ "wpctl", "get-volume", target }, function(result)
    local text = output(result)
    if text == nil then
      return
    end
    feed.audio = feed.audio or {}
    local channel = feed.audio[slot] or {}
    channel.volume = tonumber(string.match(text, "Volume:%s*([%d%.]+)"))
    channel.muted = string.find(text, "MUTED", 1, true) ~= nil
    feed.audio[slot] = channel
    publish()
  end)
  -- A device description is stable; read it once, then keep it.
  local known = feed.audio and feed.audio[slot] and feed.audio[slot].name
  if known == nil then
    run({ "wpctl", "inspect", target }, function(result)
      local text = output(result)
      if text == nil then
        return
      end
      feed.audio = feed.audio or {}
      local channel = feed.audio[slot] or {}
      channel.name = trim(string.match(text, 'node%.description%s*=%s*"([^"]+)"'))
        or trim(string.match(text, 'node%.name%s*=%s*"([^"]+)"'))
      feed.audio[slot] = channel
      publish()
    end)
  end
end

local function loadAudio()
  loadVolume("sink", "@DEFAULT_AUDIO_SINK@")
  loadVolume("source", "@DEFAULT_AUDIO_SOURCE@")
  run({ "pactl", "-f", "json", "list", "sink-inputs" }, function(result)
    local text = output(result)
    local apps = {}
    for _, input in ipairs((text and noctalia.json.decode(text)) or {}) do
      local props = input.properties or {}
      local front = input.volume and input.volume["front-left"]
      local level = front and (front.value_percent or (front.value and tonumber(front.value) / 65536))
      apps[#apps + 1] = {
        name = props["application.name"] or props["application.process.binary"] or "channel",
        volume = tonumber(string.match(tostring(level or ""), "([%d%.]+)")) / 100,
        muted = input.mute == true,
      }
    end
    feed.apps = apps
    feed.audio = feed.audio or {}
    feed.audio.apps = apps
    publish()
  end)
end

-- ---------------------------------------------------------------------------
-- Network
-- ---------------------------------------------------------------------------

local function loadNetwork(slow)
  run({ "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status" }, function(result)
    local text = output(result)
    if text == nil then
      return
    end
    local wired, wireless
    for line in string.gmatch(text, "[^\n]+") do
      local device, kind, state = string.match(line, "^([^:]+):([^:]+):([^:]+)")
      if device ~= nil then
        if kind == "ethernet" and string.sub(device, 1, 3) ~= "veth" then
          if wired == nil or state == "connected" then
            wired = { name = device, state = state }
          end
        elseif kind == "wifi" and string.sub(device, 1, 3) ~= "p2p" then
          if wireless == nil or state == "connected" then
            wireless = { name = device, state = state }
          end
        end
      end
    end
    feed.wired = wired
    feed.wireless = wireless
    publish()
  end)

  run({ "ip", "-j", "addr", "show" }, function(result)
    local text = output(result)
    local addresses = {}
    for _, iface in ipairs((text and noctalia.json.decode(text)) or {}) do
      for _, address in ipairs(iface.addr_info or {}) do
        if address.family == "inet" then
          addresses[iface.ifname] = address["local"]
        end
      end
    end
    feed.addresses = addresses
    publish()
  end)

  if not slow then
    return
  end

  run({ "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "device", "wifi", "list", "--rescan", "no" }, function(result)
    local text = output(result)
    if text == nil then
      return
    end
    local strongest, order = {}, {}
    for line in string.gmatch(text, "[^\n]+") do
      local ssid, signal = string.match(line, ":(.*):(%d+)$")
      local strength = tonumber(signal)
      if ssid ~= nil and ssid ~= "" and strength ~= nil then
        ssid = string.gsub(ssid, "\\:", ":")
        if strongest[ssid] == nil then
          order[#order + 1] = ssid
        end
        if strongest[ssid] == nil or strongest[ssid] < strength then
          strongest[ssid] = strength
        end
      end
    end
    local networks = {}
    for _, ssid in ipairs(order) do
      networks[#networks + 1] = { ssid = ssid, signal = strongest[ssid] }
    end
    table.sort(networks, function(left, right)
      return left.signal > right.signal
    end)
    feed.networks = networks
    publish()
  end)
end

-- ---------------------------------------------------------------------------
-- Bluetooth
-- ---------------------------------------------------------------------------

local function loadBluetooth(slow)
  run({ "bluetoothctl", "show" }, function(result)
    local text = output(result)
    if text == nil then
      return
    end
    feed.bt = feed.bt or {}
    feed.bt.powered = string.match(text, "Powered:%s*(%a+)") == "yes"
    feed.bt.discoverable = string.match(text, "Discoverable:%s*(%a+)") == "yes"
    publish()
  end)

  if not slow then
    return
  end

  local function devices(group, slot)
    run({ "bluetoothctl", "devices", group }, function(result)
      local text = output(result)
      if text == nil then
        return
      end
      local list = {}
      for line in string.gmatch(text, "[^\n]+") do
        local address, name = string.match(line, "^Device%s+(%S+)%s+(.+)$")
        if name ~= nil then
          list[#list + 1] = { address = address, name = name }
        end
      end
      feed.bt = feed.bt or {}
      feed.bt[slot] = list
      publish()
    end)
  end
  devices("Paired", "paired")
  devices("Connected", "connected")
end

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------

local function loadMedia()
  run({ "playerctl", "metadata", "--format", META_FORMAT }, function(result)
    local text = output(result)
    local line = text and firstLine(text)
    if line == nil or line == "" then
      feed.media = nil
      publish()
      return
    end
    local player, title, artist, length, position = string.match(
      line,
      "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"
    )
    feed.media = {
      player = player,
      app = appFor(player),
      title = title,
      artist = artist,
      length = tonumber(length),
      position = tonumber(position),
      status = feed.media and feed.media.status or nil,
    }
    publish()
  end)
  run({ "playerctl", "status" }, function(result)
    local text = output(result)
    feed.media = feed.media or {}
    feed.media.status = text and trim(firstLine(text)) or nil
    publish()
  end)
end

-- ---------------------------------------------------------------------------
-- Poll and requests
-- ---------------------------------------------------------------------------

-- A full sweep, in five stages. Each stage is small enough to stay inside the
-- per-callback CPU budget; a drawer open for five seconds has seen every group
-- refreshed.
local STAGES = {
  function()
    loadProvenance()
    loadSupplies()
    loadPower()
  end,
  loadAudio,
  function()
    loadNetwork(true)
  end,
  function()
    loadBluetooth(true)
  end,
  loadMedia,
}

local stage = 0

local function handle(request)
  local kind = request.kind
  local payload = request.payload or {}
  if kind == "profile" and payload.id ~= nil then
    run({ "powerprofilesctl", "set", payload.id }, function()
      loadPower()
    end)
  elseif kind == "mute" then
    local target = payload.slot == "source" and "@DEFAULT_AUDIO_SOURCE@" or "@DEFAULT_AUDIO_SINK@"
    run({ "wpctl", "set-mute", target, "toggle" }, function()
      loadAudio()
    end)
  elseif kind == "link" and payload.name ~= nil then
    run({ "nmcli", "device", payload.on and "connect" or "disconnect", payload.name }, function()
      loadNetwork(false)
    end)
  elseif kind == "wifi" and payload.ssid ~= nil then
    run({ "nmcli", "device", "wifi", "connect", payload.ssid }, function(result)
      if (result.exitCode or 1) ~= 0 then
        noctalia.notifyError("Wi-Fi", firstLine(result.stderr) or payload.ssid)
      end
      loadNetwork(true)
    end)
  elseif kind == "bluetooth-power" then
    run({ "bluetoothctl", "power", payload.on and "on" or "off" }, function()
      loadBluetooth(false)
    end)
  elseif kind == "bluetooth-discoverable" then
    run({ "bluetoothctl", "discoverable", payload.on and "on" or "off" }, function()
      loadBluetooth(false)
    end)
  elseif kind == "media" and payload.action ~= nil then
    run({ "playerctl", payload.action }, function()
      loadMedia()
    end)
  elseif kind == "refresh" then
    -- Restart the sweep rather than running it here: the next tick (at most a
    -- second away) begins a fresh pass, inside the callback budget.
    stage = 0
  end
end

noctalia.setUpdateInterval(INTERVAL_MS)

function update()
  stage = stage % #STAGES + 1
  STAGES[stage]()
  publish()
end

noctalia.state.watch("request_rev", function(value)
  local rev = tonumber(value) or 0
  if rev == lastRequestRev then
    return
  end
  lastRequestRev = rev
  handle(noctalia.state.get("request") or {})
end)

-- Seed the two stages a drawer needs first (provenance and the audio strip);
-- the rest arrive on the next ticks. The load budget is larger than a
-- callback's, but there is no reason to spend it on fifteen spawns.
STAGES[1]()
STAGES[2]()
publish()
