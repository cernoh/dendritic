--!nonstrict
-- The six bar families, against the stub host.
-- Assembled by ../../../tests/run-museum-tests.sh.

local function tags(count, active)
  local out = {}
  for index = 1, count do
    table.insert(out, {
      index = index,
      is_active = index == active,
      is_urgent = false,
      client_count = index <= 2 and 1 or 0,
      layout = "S",
    })
  end
  return out
end

local ALL_TAGS = {
  all_tags = {
    { monitor = "DP-3", tags = tags(9, 1) },
    { monitor = "DP-2", tags = tags(9, 2) },
    { monitor = "DP-1", tags = tags(9, 1) },
  },
}

local STATS = { ramUsedMb = 6861, cpuUsage = 9, gpuUsage = 10, cpuTempC = 53 }
local DRIVES = { tempC = 35, degradedPct = 37 }
local AUDIO = { volume = 53, muted = false, brightness = 100 }
local MEDIA = { status = "Playing", title = "(3) Meet the Gruutmans - YouTube" }

-- The shipped English strings; the stub's tr() falls back to the key.
stub.rec.tr = {
  ["bar.now_viewing"] = "Now viewing",
  ["bar.no_window"] = "No window",
  ["bar.machine"] = "Machine",
  ["bar.thermal"] = "Thermal",
  ["bar.no_exhibit"] = "No exhibit",
  ["bar.media"] = "Now exhibiting",
  ["bar.audio"] = "Audio",
  ["bar.notifications"] = "Notices",
  ["bar.clipboard"] = "Clipboard",
  ["bar.network"] = "Network",
  ["bar.bluetooth"] = "Bluetooth",
  ["bar.session"] = "Session",
  ["key.ram"] = "ram",
  ["key.cpu"] = "cpu",
  ["key.gpu"] = "gpu",
  ["key.drv"] = "drv",
  ["key.vol"] = "vol",
  ["key.bri"] = "bri",
}

-- ── halls ─────────────────────────────────────────────────────────────────

local picked = nil
local rail = bar.halls({
  tags = { { index = 1, is_active = true, client_count = 3 }, { index = 2, is_active = false, client_count = 1 } },
  onSelect = function(index)
    picked = index
  end,
})
assert(rail.type == "row", "halls root is a row")
assert(#rail.children == 2, "two populated halls")
assert(rail.children[1].props.variant == "primary", "active hall is brass")
assert(rail.children[2].props.variant == "ghost", "inactive hall is quiet")
assert(rail.children[1].props.text == "I" and rail.children[2].props.text == "II", "roman numerals")
assert(rail.children[1].props.width == museum.width.hallPlate, "hall plate width is capped per plate")
assert(rail.props.width <= museum.width.halls, "halls rail within cap")
rail.children[2].props.onClick()
assert(picked == 2, "click reports the hall index")

local nine = bar.halls({ tags = tags(9, 1), onSelect = function() end })
assert(#nine.children == 9, "nine halls")
assert(nine.props.width == museum.width.halls, "nine halls sit exactly on the cap")

local none = bar.halls({ tags = {}, onSelect = function() end })
assert(none == nil, "no populated halls renders nothing (widget hides)")

local filtered = nil
do
  local mangoLocal = mango
  local list = mangoLocal.hallTags(ALL_TAGS, "DP-1", 0, true)
  filtered = list
end
assert(#filtered == 2, "hide_when_empty keeps the active hall and populated halls")

-- ── wall label ────────────────────────────────────────────────────────────

local label = bar.label({ title = string.rep("x", 400), maxLength = 260 })
assert(label.props.fill == "on_surface", "label is a paper slip")
assert(label.props.width == museum.width.label, "label width cap")
assert(#label.children[2].props.text <= 260, "title is truncated to max_length")
assert(string.sub(label.children[2].props.text, -3) == "…", "truncation is marked")

local emptyLabel = bar.label({ title = "" })
assert(emptyLabel.children[2].props.text == "No window", "empty title falls back to a translated word")

-- ── MACHINE ───────────────────────────────────────────────────────────────

local machine = bar.machine({ stats = STATS })
assert(machine.props.width == museum.width.machine, "machine plate cap")
local texts = {}
stub.findAll(machine, function(node)
  if node.type == "label" then
    table.insert(texts, node.props.text)
  end
  return false
end)
local joined = table.concat(texts, "|")
assert(string.find(joined, "Machine", 1, true) ~= nil, "machine caption")
assert(string.find(joined, "6.7G", 1, true) ~= nil, "ram as gigabytes")
assert(string.find(joined, "9%", 1, true) ~= nil, "cpu percent")
assert(string.find(joined, "10%", 1, true) ~= nil, "gpu percent")

local noGpu = bar.machine({ stats = STATS, showGpu = false })
local gpuTexts = {}
stub.findAll(noGpu, function(node)
  if node.type == "label" then
    table.insert(gpuTexts, node.props.text)
  end
  return false
end)
assert(string.find(table.concat(gpuTexts, "|"), "gpu", 1, true) == nil, "gpu cell hidden by config")

local absent = bar.machine({ stats = nil })
local dash = stub.find(absent, function(node)
  return node.type == "label" and node.props.text == "—"
end)
assert(dash ~= nil, "an absent sample renders a dash, not a zero")

-- ── clock ─────────────────────────────────────────────────────────────────

local clock = bar.clock({ time = "15:15", date = "Wed 21 Oct" })
assert(clock.props.width == museum.width.clock, "clock cap")
assert(#clock.children == 2, "clock is two lines")
assert(clock.children[1].props.color == "primary", "time is brass")
assert(clock.children[1].props.fontSize > clock.children[2].props.fontSize, "time is the loud line")
assert(clock.children[2].props.text == "Wed 21 Oct", "date line")

-- ── THERMAL + fuel gauge ──────────────────────────────────────────────────

local thermal = bar.thermal({ stats = STATS, drives = DRIVES })
assert(thermal.type == "row", "thermal entry is one row")
assert(#thermal.children == 2, "plaque + gauge")

local thermalTexts = {}
stub.findAll(thermal, function(node)
  if node.type == "label" then
    table.insert(thermalTexts, node.props.text)
  end
  return false
end)
local thermalJoined = table.concat(thermalTexts, "|")
assert(string.find(thermalJoined, "53°C", 1, true) ~= nil, "cpu temperature")
assert(string.find(thermalJoined, "35°C", 1, true) ~= nil, "drive temperature")
assert(string.find(thermalJoined, "37%", 1, true) ~= nil, "degradation numeral")

local gaugeRow = stub.find(thermal, function(node)
  return node.props ~= nil and node.props.key == "drive-gauge"
end)
assert(gaugeRow ~= nil, "gauge present")
assert(stub.count(gaugeRow, "box") == 10, "ten fuel segments")

local noGauge = bar.thermal({ stats = STATS, drives = DRIVES, showGauge = false })
assert(noGauge.type == "column", "gauge can be disabled")
assert(stub.find(noGauge, function(node)
  return node.props ~= nil and node.props.key == "seg-1"
end) == nil, "no segments without the gauge")

-- ── tray ──────────────────────────────────────────────────────────────────

stub.reset()
local tray = bar.tray({ media = MEDIA, audio = AUDIO, unread = 2 })
assert(tray.type == "row", "tray root")
assert(stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "exhibit"
end) ~= nil, "exhibit plate")
assert(stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "tray-plate"
end) ~= nil, "tray plate")
assert(stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "wax-seal"
end) ~= nil, "wax seal with unread count")
assert(stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "audio-plate"
end) ~= nil, "audio plate")

local playing = stub.find(tray, function(node)
  return node.type == "glyph" and node.props.name == "player-pause"
end)
assert(playing ~= nil, "playing exhibit shows a pause glyph")
assert(playing.props.color == "primary", "playing exhibit is brass")

local quiet = bar.tray({ media = nil, audio = AUDIO, unread = 0 })
assert(stub.find(quiet, function(node)
  return node.props ~= nil and node.props.key == "wax-seal"
end) == nil, "seal hides at zero")
local noExhibit = stub.find(quiet, function(node)
  return node.type == "label" and node.props.text == "No exhibit"
end)
assert(noExhibit ~= nil, "idle exhibit reads No exhibit")

stub.rec.async = {}
local networkButton = stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "tray-network"
end)
assert(networkButton ~= nil, "tray plate has the network glyph")
networkButton.props.onClick()
assert(#stub.rec.async == 1, "glyph click runs one IPC command")
assert(stub.rec.async[1][1] == "noctalia", "IPC uses the noctalia CLI")
assert(stub.rec.async[1][4] == "control-center" and stub.rec.async[1][5] == "network", "network tab opens")

stub.rec.async = {}
local power = stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "power"
end)
assert(power.props.variant == "primary", "power is the one brass button")
power.props.onClick()
assert(stub.rec.async[1][4] == "session", "power opens the session panel")

stub.rec.async = {}
local seal = stub.find(tray, function(node)
  return node.props ~= nil and node.props.key == "wax-seal"
end)
seal.props.onClick()
assert(stub.rec.async[1][5] == "notifications", "seal opens notices")

local noAudio = bar.tray({ media = nil, audio = AUDIO, unread = 0, showAudio = false })
assert(stub.find(noAudio, function(node)
  return node.props ~= nil and node.props.key == "audio-plate"
end) == nil, "audio plate can be disabled")

-- ── vertical bars hide rather than render a broken column ────────────────

stub.rec.vertical = true
assert(bar.horizontal() == false, "vertical bar is refused")
stub.rec.vertical = false
assert(bar.horizontal() == true, "horizontal bar is rendered")

-- ── material discipline across all six trees ─────────────────────────────

local every = {
  bar.halls({ tags = tags(9, 1), onSelect = function() end }),
  bar.label({ title = "noctalia msg screens ~" }),
  bar.machine({ stats = STATS }),
  bar.clock({ time = "15:15", date = "Wed 21 Oct" }),
  bar.thermal({ stats = STATS, drives = DRIVES }),
  bar.tray({ media = MEDIA, audio = AUDIO, unread = 2 }),
}
for index, tree in ipairs(every) do
  assert(tree ~= nil, "widget " .. index .. " renders")
  for _, color in ipairs(stub.colors(tree)) do
    if string.sub(color, 1, 1) == "#" then
      local allowed = false
      for _, exception in ipairs(museum.hexExceptions) do
        if color == exception then
          allowed = true
        end
      end
      assert(allowed, "widget " .. index .. " emits unexpected hex " .. color)
    end
  end
end

print(string.format("bar.luau: ok (%d px worst-case bar)", museum.widthBudget()))
