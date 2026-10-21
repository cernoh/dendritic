--!nonstrict
-- The catalogue drawer's tests (PLAN phase 4). Assembled and run by
-- ../../../tests/run-museum-tests.sh, which concatenates the stub host, the
-- library modules and panel.luau into one chunk — the Luau CLI gives every
-- required module its own environment, so a plain `require` cannot reach the
-- host globals.
--
-- The panel is a renderer: it reads the service's `drawer` feed from the state
-- channel and the synchronous plugin API, and posts work back as requests.
-- So the fixture here is a *feed*, and what is asserted is:
--   * the rail has exactly ten wings and each one opens a section;
--   * every section renders its feed record, with the live value visible;
--   * every control posts the request the service understands;
--   * empty states are stamped in words, not blank;
--   * the drawer's colors are palette roles (plus the three allowed hexes) and
--     every prop is one the host's reconciler knows.

-- ── fixtures ──────────────────────────────────────────────────────────────

-- No stub.reset() here: panel.luau registers its state watchers when the chunk
-- loads, and reset() would clear them before the driver can fire them.

-- The plugin's own translations, decoded through the stub's JSON reader, so
-- every textual assertion below reads real copy instead of a key name.
do
  local decoded, err = stub.json.decode(__translationsJson)
  assert(decoded ~= nil, "translations/en.json decodes: " .. tostring(err))
  assert(decoded["title.system"] ~= nil, "the translations carry the drawer copy")
  stub.rec.tr = decoded
end

stub.noctalia.getSetting = function(path)
  return ({
    ["location.address"] = "",
    ["location.auto_locate"] = false,
    ["location.sunrise"] = "07:12",
    ["location.sunset"] = "18:02",
    ["calendar.enabled"] = false,
  })[path]
end

stub.noctalia.systemStats = function()
  return {
    cpu = { usagePercent = 13, tempC = 66 },
    ram = { usagePercent = 38, usedMb = 12185, totalMb = 32000 },
    swap = { usedMb = 1024, totalMb = 9000 },
    gpu = { usagePercent = 44, tempC = 46, vramUsedBytes = 3435973836 },
    net = { rxBytesPerSec = 4200, txBytesPerSec = 128 },
    loadAvg = { 5.59, 7.78, 7.37 },
  }
end

stub.noctalia.outputs = function()
  return {
    { name = "DP-1", description = "AOC 24G2W1G3", width = 1920, height = 1080, x = 0, y = 0, scale = 1, focused = true },
    { name = "DP-2", description = "Huawei AD80HW", width = 1920, height = 1080, x = 1920, y = 0, scale = 1 },
    { name = "DP-3", description = "", width = 0, height = 0, x = 0, y = 0, scale = 1 },
  }
end

stub.noctalia.diskMounts = function()
  return {
    { path = "/", source = "/dev/nvme0n1p2", filesystem = "btrfs" },
    { path = "/mnt/2tb-ext4", source = "/dev/sda1", filesystem = "ext4" },
  }
end

stub.noctalia.diskStats = function(path)
  if path == "/" then
    return { usagePercent = 52, totalBytes = 489600000000, freeBytes = 235000000000 }
  end
  return { usagePercent = 15, totalBytes = 2000000000000, freeBytes = 1700000000000 }
end

-- What catalogue.luau publishes on `drawer`.
stub.set("drawer", {
  maker = "AMD Ryzen 7 3700X",
  gpu = "NVIDIA GeForce RTX 3060",
  origin = "NixOS 26.11 (Xanthe)",
  substrate = "7.2.11",
  frame = "mango",
  hostname = "NIXPC",
  uptime = 6420,
  supplies = { { name = "hidpp_battery_0", kind = "Battery", capacity = 100, status = "Discharging" } },
  profile = "performance",
  audio = {
    sink = { name = "AB13X Headset Adapter Analog Stereo", volume = 0.53, muted = false },
    source = { name = "USB PnP Audio Device Mono", volume = 1.0, muted = true },
    apps = { { name = "Brave", volume = 1.0, muted = false } },
  },
  wired = { name = "enp5s0", state = "connected" },
  wireless = { name = "wlp4s0", state = "disconnected" },
  addresses = { enp5s0 = "192.168.1.121" },
  networks = {
    { ssid = "Onecom_5EF2", signal = 90 },
    { ssid = "SKYXFXSL", signal = 49 },
    { ssid = "DIRECT-7F-HP DeskJet 2700 series", signal = 39 },
  },
  bt = {
    powered = true,
    discoverable = false,
    paired = { { address = "AA:BB:CC:DD:EE:FF", name = "DualSense Wireless Controller" } },
    connected = {},
  },
  media = {
    player = "brave",
    app = "Brave",
    title = "(3) Meet the Gruutmans - YouTube",
    artist = "",
    length = 3766501000,
    position = 1305433229,
    status = "Paused",
  },
})

-- ── helpers ───────────────────────────────────────────────────────────────

local rendered, closed

local function findKey(tree, key)
  return stub.find(tree, function(node)
    return node.props.key == key
  end)
end

local function labels(tree, out)
  out = out or {}
  if tree == nil then
    return out
  end
  if tree.type == "label" and tree.props.text ~= nil then
    table.insert(out, tree.props.text)
  end
  for _, child in ipairs(tree.children or {}) do
    labels(child, out)
  end
  return out
end

local function hasText(tree, text)
  for _, label in ipairs(labels(tree)) do
    if label == text then
      return true
    end
  end
  return false
end

local function containsText(tree, fragment)
  for _, label in ipairs(labels(tree)) do
    if string.find(label, fragment, 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function keyed(tree, prefix)
  return stub.findAll(tree, function(node)
    local key = node.props.key
    return type(key) == "string" and string.sub(key, 1, #prefix) == prefix
  end)
end

local function buttonsByText(tree, text)
  return stub.findAll(tree, function(node)
    return node.type == "button" and node.props.text == text
  end)
end

-- The last request the drawer posted to the service.
local function lastRequest()
  local request = stub.rec.state["request"]
  assert(request ~= nil, "the drawer posts a request")
  return request.kind, request.payload or {}
end

local function requestCount()
  return tonumber(stub.rec.state["request_rev"]) or 0
end

local function openSection(id)
  local row = findKey(rendered, "rail-" .. id)
  assert(row ~= nil, "rail entry " .. id .. " exists")
  row.props.onClick()
  return rendered
end

-- Every prop the host's reconciler accepts, copied from
-- src/ui/ui_tree_reconciler.cpp `knownProps`. An unknown prop is a loud skip
-- in the shell, so a typo must fail here instead.
local ALLOWED = {
  column = { width = true, height = true, flexGrow = true, opacity = true, visible = true, gap = true, padding = true, paddingH = true, paddingV = true, align = true, justify = true, fill = true, radius = true, border = true, borderWidth = true, minWidth = true, minHeight = true, onClick = true, onHover = true, tooltip = true },
  row = { width = true, height = true, flexGrow = true, opacity = true, visible = true, gap = true, padding = true, paddingH = true, paddingV = true, align = true, justify = true, fill = true, radius = true, border = true, borderWidth = true, minWidth = true, minHeight = true, onClick = true, onHover = true, tooltip = true },
  box = { width = true, height = true, flexGrow = true, opacity = true, visible = true, fill = true, radius = true, border = true, borderWidth = true, softness = true, onClick = true, onHover = true, tooltip = true },
  label = { width = true, height = true, flexGrow = true, opacity = true, visible = true, text = true, fontSize = true, color = true, fontWeight = true, maxWidth = true, maxLines = true, textAlign = true, fontFamily = true, baseline = true },
  glyph = { width = true, height = true, flexGrow = true, opacity = true, visible = true, name = true, size = true, color = true },
  image = { width = true, height = true, flexGrow = true, opacity = true, visible = true, path = true, radius = true, fit = true, border = true, borderWidth = true, onClick = true, onHover = true, tooltip = true },
  separator = { width = true, height = true, flexGrow = true, opacity = true, visible = true, thickness = true, color = true, spacing = true, orientation = true },
  spacer = { width = true, height = true, flexGrow = true, opacity = true, visible = true },
  progress = { width = true, height = true, flexGrow = true, opacity = true, visible = true, progress = true, fill = true, track = true, radius = true },
  button = { width = true, height = true, flexGrow = true, opacity = true, visible = true, text = true, glyph = true, fontSize = true, glyphSize = true, variant = true, contentAlign = true, enabled = true, selected = true, onClick = true, onRightClick = true, tooltip = true, controlSize = true, onHover = true },
  scroll = { width = true, height = true, flexGrow = true, opacity = true, visible = true, fill = true, radius = true, border = true, borderWidth = true, gap = true, padding = true, paddingH = true, paddingV = true, align = true, justify = true, stickToBottom = true, onScroll = true, scrollToBottomRev = true, revealKey = true },
  graph = { width = true, height = true, flexGrow = true, opacity = true, visible = true, values = true, values2 = true, color = true, color2 = true, lineWidth = true, fillOpacity = true, onPointerMove = true, onPointerLeave = true },
}

local function validate(tree, path)
  path = path or "root"
  assert(tree ~= nil, "node at " .. path)
  assert(type(tree.type) == "string", "type at " .. path)
  local allowed = ALLOWED[tree.type]
  assert(allowed ~= nil, "unknown control type '" .. tostring(tree.type) .. "' at " .. path)
  assert(tree.props.key == nil or type(tree.props.key) == "string", "key must be a string at " .. path)
  for prop, value in pairs(tree.props) do
    assert(prop == "key" or allowed[prop] == true, "unknown prop '" .. tostring(prop) .. "' on " .. tree.type .. " at " .. path)
    assert(value ~= nil, "nil prop '" .. tostring(prop) .. "' at " .. path)
  end
  for index, child in ipairs(tree.children or {}) do
    validate(child, path .. "/" .. tostring(tree.type) .. "[" .. tostring(index) .. "]")
  end
end

-- ── the drawer opens ──────────────────────────────────────────────────────

panel.render = function(tree)
  rendered = tree
end
panel.close = function()
  closed = true
end
panel.setWantsSecondTicks = function() end

onOpen()

assert(rendered ~= nil, "the drawer renders on open")
assert(rendered.props.key == "museum-drawer", "the drawer root is keyed")
assert(rendered.props.fill == "surface", "the drawer body is walnut")
assert(lastRequest() == "refresh", "opening the drawer asks the service for a fresh feed")
validate(rendered)

local wings = stub.findAll(rendered, function(node)
  local key = node.props.key
  return type(key) == "string" and string.sub(key, 1, 5) == "rail-" and key ~= "rail-head"
end)
assert(#wings == 10, "the Wing Index has ten wings, got " .. tostring(#wings))

local order = {
  "system", "power", "audio", "display", "network",
  "bluetooth", "weather", "calendar", "notices", "media",
}
for index, id in ipairs(order) do
  local row = findKey(rendered, "rail-" .. id)
  assert(row ~= nil, "wing " .. id .. " is in the rail")
  assert(row.children[2].props.text == stub.rec.tr["wing." .. id], "wing " .. id .. " is named")
  assert(row.children[3].props.text == museum.roman(index), "wing " .. id .. " carries numeral " .. museum.roman(index))
end

assert(findKey(rendered, "rail-system").props.fill == "primary", "the active wing is brass")
assert(findKey(rendered, "rail-media").props.fill == "surface_variant", "an inactive wing is walnut (explicit: a retained row keeps its last fill)")

-- ── I — System ────────────────────────────────────────────────────────────

local system = openSection("system")
assert(findKey(system, "section-system") ~= nil, "system section renders")
assert(findKey(system, "drawer-title").props.text == stub.rec.tr["title.system"], "system header")
assert(findKey(system, "drawer-accession").props.text == "SPECIMEN NIXPC", "system accession names the host")
assert(hasText(system, "13%"), "cpu instrument reads the live value")
assert(hasText(system, "66°C"), "cpu temperature is in patina")
assert(hasText(system, "AMD Ryzen 7 3700X"), "provenance maker")
assert(hasText(system, "NixOS 26.11 (Xanthe)"), "provenance origin")
assert(hasText(system, "7.2.11"), "provenance substrate")
assert(hasText(system, "mango"), "provenance frame")
assert(hasText(system, "1h 47m"), "on-loan uptime")
assert(hasText(system, "254.6 / 489.6 GB"), "inventory mount fill")
assert(hasText(system, "2tb-ext4"), "inventory keeps a mount's own name")
assert(#keyed(system, "seg-") >= 40, "instruments and mounts draw gauges")

-- ── II — Power ────────────────────────────────────────────────────────────

local power = openSection("power")
assert(findKey(power, "section-power") ~= nil, "power section renders")
local engaged = buttonsByText(power, "PERFORMANCE")
assert(#engaged == 1, "the profile throw shows its three positions")
assert(engaged[1].props.variant == "primary", "the active profile is seated")
local before = requestCount()
engaged[1].props.onClick()
assert(requestCount() == before + 1, "a throw bumps the request revision")
local kind, payload = lastRequest()
assert(kind == "profile" and payload.id == "performance", "the throw asks for the profile")
assert(hasText(power, "100%"), "the mouse's charge is a gauge and a number")

-- ── III — Audio ───────────────────────────────────────────────────────────

local audio = openSection("audio")
assert(findKey(audio, "section-audio") ~= nil, "audio section renders")
assert(hasText(audio, "AB13X Headset Adapter Analog Stereo"), "output device named")
assert(hasText(audio, "USB PnP Audio Device Mono"), "input device named")
assert(hasText(audio, "53%"), "output level")
assert(hasText(audio, "Brave"), "application channel")
local offButtons = buttonsByText(audio, "OFF")
assert(#offButtons >= 2, "each channel has a mute throw")
offButtons[1].props.onClick()
kind, payload = lastRequest()
assert(kind == "mute" and payload.slot == "sink", "the mute throw asks the service to toggle the sink")

-- ── IV — Display ──────────────────────────────────────────────────────────

local display = openSection("display")
assert(findKey(display, "section-display") ~= nil, "display section renders")
assert(findKey(display, "display-DP-1") ~= nil, "one plate per lamp")
assert(findKey(display, "display-DP-3").props.opacity == 0.55, "a dark lamp dims its plate")
assert(hasText(display, "1920 × 1080"), "format on ruled lines")
assert(hasText(display, "3 LAMPS"), "accession counts the lamps")

-- ── V — Network ───────────────────────────────────────────────────────────

local network = openSection("network")
assert(findKey(network, "section-network") ~= nil, "network section renders")
assert(hasText(network, "enp5s0"), "wired interface")
assert(hasText(network, "192.168.1.121"), "wired address")
assert(hasText(network, "Onecom_5EF2"), "wireless registry lists networks")
assert(hasText(network, "90%"), "signal strength")
local firstNetwork = findKey(network, "network-wifi-1")
assert(firstNetwork ~= nil, "a network is a row")
firstNetwork.props.onClick()
kind, payload = lastRequest()
assert(kind == "wifi" and payload.ssid == "Onecom_5EF2", "a network row asks to join it")
local linkOff = buttonsByText(network, "OFF")
assert(#linkOff >= 1, "the wired link has a throw")
linkOff[1].props.onClick()
kind, payload = lastRequest()
assert(kind == "link" and payload.name == "enp5s0" and payload.on == false, "the link throw asks for a disconnect")

-- ── VI — Bluetooth ────────────────────────────────────────────────────────

local bluetooth = openSection("bluetooth")
assert(findKey(bluetooth, "section-bluetooth") ~= nil, "bluetooth section renders")
assert(findKey(bluetooth, "bluetooth-radio") ~= nil, "radio plate")
assert(hasText(bluetooth, "DualSense Wireless Controller"), "paired holding")
local onButtons = buttonsByText(bluetooth, "ON")
assert(#onButtons >= 1, "the radio throw shows ON")
onButtons[1].props.onClick()
kind, payload = lastRequest()
assert(kind == "bluetooth-power" and payload.on == true, "the radio throw asks for power")

-- ── VII — Weather ─────────────────────────────────────────────────────────

local weather = openSection("weather")
assert(findKey(weather, "section-weather") ~= nil, "weather section renders")
assert(findKey(weather, "weather-unlocated") ~= nil, "the empty state is a slip")
assert(hasText(weather, "UNLOCATED"), "the slip is stamped in words")
assert(hasText(weather, "07:12"), "ephemeris reads the configured sunrise")
assert(findKey(weather, "weather-tabs-tab-1") ~= nil, "index tabs")

-- ── VIII — Calendar ───────────────────────────────────────────────────────

local calendar = openSection("calendar")
assert(findKey(calendar, "section-calendar") ~= nil, "calendar section renders")
local days = keyed(calendar, "calendar-day-")
assert(#days % 7 == 0 and #days >= 28, "whole weeks on the plate, got " .. tostring(#days))
local today = os.date("*t")
local todayCell = findKey(calendar, "calendar-day-" .. string.format("%04d-%02d-%02d", today.year, today.month, today.day))
assert(todayCell ~= nil, "today is on the plate")
assert(todayCell.props.fill == "primary", "today is a brass seal")
local monthLabel = findKey(calendar, "calendar-month").children[2].children[2].props.text
findKey(calendar, "calendar-next").props.onClick()
assert(findKey(rendered, "calendar-month").children[2].children[2].props.text ~= monthLabel, "the month advances")
findKey(rendered, "calendar-prev").props.onClick()
assert(findKey(rendered, "calendar-month").children[2].children[2].props.text == monthLabel, "the month returns")
assert(hasText(rendered, "NO EVENTS"), "the wall text is stamped")
assert(containsText(rendered, stub.rec.tr["calendar.disabled.body"]), "the empty register is explained")

-- ── IX — Notices ──────────────────────────────────────────────────────────

local notices = openSection("notices")
assert(findKey(notices, "section-notices") ~= nil, "notices section renders")
assert(findKey(notices, "notices-empty") ~= nil, "an empty register is a slip")
assert(hasText(notices, "EMPTY"), "the empty register is stamped")

stub.set("unread", 3)
assert(containsText(rendered, "3 unread"), "the shell's unread count is named, not hidden")

stub.set("notifications", {
  { title = "Done in 17m 41s", app = "Terminal", body = "nixos-rebuild switch", age_days = 1, stamp = "filed" },
  { title = "Graykeith: Translator Daemonica", app = "Brave", body = "MAL-Sync · Chapter 6", age_days = 0, stamp = "received" },
  { title = "Dragon no I de Oyasumi", app = "Brave", body = "MAL-Sync", age_days = 3, stamp = "received" },
})
assert(findKey(rendered, "notice-1") ~= nil, "one slip per notice")
assert(hasText(rendered, "RECEIVED"), "a notice is stamped RECEIVED")
assert(hasText(rendered, "FILED"), "a filed notice is stamped FILED")
assert(hasText(rendered, "ACC. 0001"), "the slip carries an accession number")
assert(findKey(rendered, "notices-tabs-tab-2") ~= nil, "date index tabs")
findKey(rendered, "notices-tabs-tab-2").props.onClick()
assert(findKey(rendered, "notice-2") ~= nil, "TODAY keeps today's notice")
assert(findKey(rendered, "notice-1") == nil, "TODAY drops yesterday's")
findKey(rendered, "notices-tabs-tab-1").props.onClick()
assert(findKey(rendered, "notice-1") ~= nil, "ALL restores the register")
stub.set("notifications", nil)
assert(findKey(rendered, "notices-empty") ~= nil, "the register empties again")

-- ── X — Media ─────────────────────────────────────────────────────────────

local media = openSection("media")
assert(findKey(media, "section-media") ~= nil, "media section renders")
assert(hasText(media, "(3) Meet the Gruutmans - YouTube"), "the wall label carries the title")
assert(hasText(media, "Brave"), "the label names the application")
assert(hasText(media, "DURATION 1:02:46"), "duration from MPRIS")
assert(hasText(media, "ELAPSED 21:45"), "position from MPRIS")
local pause = findKey(media, "media-playpause")
assert(pause.props.glyph == "player-play", "a paused exhibit offers play")
pause.props.onClick()
kind, payload = lastRequest()
assert(kind == "media" and payload.action == "play-pause", "the transport asks the service to drive the player")
assert(findKey(media, "media-well") ~= nil, "the oscillograph is a framed well")
assert(#keyed(media, "media-band-") == 32, "32 bands")
assert(hasText(media, "NO SIGNAL"), "without a service the well says so")

local waveform = {}
for index = 1, 32 do
  waveform[index] = index / 32
end
stub.set("bands", waveform)
assert(findKey(rendered, "media-band-32").props.height > 50, "a published waveform drives the bands")
stub.set("bands", nil)

-- ── an unlit gallery ──────────────────────────────────────────────────────

stub.set("drawer", nil)
stub.noctalia.outputs = function()
  return {}
end
stub.noctalia.systemStats = function()
  return nil
end
onOpen()
local bare = openSection("system")
assert(hasText(bare, "—"), "a missing probe reads as a dash")
assert(findKey(bare, "drawer-accession").props.text == "SPECIMEN —", "the specimen is blank without a host")
assert(hasText(openSection("display"), stub.rec.tr["empty.lamps"]), "no output is a stamped slip")

-- ── deep link ─────────────────────────────────────────────────────────────

onOpen("calendar")
assert(findKey(rendered, "section-calendar") ~= nil, "onOpen context opens straight onto a wing")
assert(findKey(rendered, "rail-calendar").props.fill == "primary", "the deep-linked wing is lit")

-- ── materials and props ───────────────────────────────────────────────────

local allowedHex = {}
for _, hex in ipairs(museum.hexExceptions) do
  allowedHex[hex] = true
end
for _, id in ipairs(order) do
  local tree = openSection(id)
  validate(tree)
  for _, color in ipairs(stub.colors(tree)) do
    if string.sub(color, 1, 1) == "#" then
      assert(allowedHex[color], "unexpected hex " .. color .. " in " .. id)
    else
      assert(string.match(color, "^[%w_]+$") or string.match(color, "^[%w_]+/%d+%.?%d*$"), "color is a role or a role/alpha: " .. color)
    end
  end
end

-- ── drawer geometry ───────────────────────────────────────────────────────

local plate = drawer.plate({ caption = "Provenance", note = "live" }, { ui.label({ text = "x" }) })
assert(plate.props.padding == 13, "a drawer plate breathes")
assert(plate.props.flexGrow == nil, "a plate only flexes when asked")
assert(plate.props.fill == "surface_variant", "raised walnut")
assert(plate.children[1].type == "row", "the caption is a row")

local slip = drawer.slip({ stamp = "Received", title = "Wall text", line = "body", footerLeft = "a", footerRight = "b" })
assert(slip.props.fill == "on_surface", "the slip is the inverted surface")
assert(slip.children[1].children[2].type == "row", "the stamp is an axis-aligned bordered row")
assert(slip.children[1].children[2].props.borderWidth == 2, "the stamp is 2 px")

local ledger = drawer.ledger({ cells = { { key = "Maker", value = "AMD" }, { key = "Ram", value = "38%", gauge = 0.38 } } })
assert(ledger.children[1].children[2].type == "box", "the leader is a 1 px box, not a fading separator")
assert(ledger.children[1].children[2].props.height == 1, "the leader is 1 px")
assert(ledger.children[2].children[3].type == "row", "a gauge row carries its meter")

print("panel.luau: ok (10 wings, " .. tostring(#wings) .. " rail entries)")
