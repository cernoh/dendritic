--!nonstrict
-- Desktop tiles (PLAN phase 5) — stub-host assertions.
--
-- Assembled and run by tests/run-desktop-tests.sh: the Luau CLI gives every
-- required module its own environment, so the stub host, the libraries, the
-- driver and the three entry scripts are concatenated into one chunk.
-- Assertions are on the rendered ui.* tree, never on pixels.

-- ── the instrument board ──────────────────────────────────────────────────

-- The stub returns the key when no translation is loaded; seed the strings
-- the tiles render so the assertions read like the live shell.
local strings = {
  ["caption.instruments"] = "Instrument panel",
  ["caption.monthplate"] = "Month plate",
  ["caption.walltext"] = "Wall text",
  ["key.gpu"] = "gpu",
  ["key.cpu"] = "cpu",
  ["key.ram"] = "ram",
  ["key.vram"] = "vram",
  ["key.load"] = "load",
  ["key.swap"] = "swap",
  ["note.probe"] = "no probe",
  ["action.previous"] = "Previous",
  ["action.next"] = "Next",
  ["weekday.mon"] = "Mon",
  ["weekday.tue"] = "Tue",
  ["weekday.wed"] = "Wed",
  ["weekday.thu"] = "Thu",
  ["weekday.fri"] = "Fri",
  ["weekday.sat"] = "Sat",
  ["weekday.sun"] = "Sun",
  ["desktop.accession"] = "No. 1988354527",
  ["desktop.month.noevents"] = "— no events scheduled.",
}
for key, value in pairs(strings) do
  stub.rec.tr[key] = value
end

local stats = {
  cpuUsage = 9,
  cpuTempC = 53,
  gpuUsage = 10,
  gpuTempC = 57,
  vramUsedBytes = 0.9 * 1024 * 1024 * 1024,
  vramTotalBytes = 8 * 1024 * 1024 * 1024,
  ramUsagePercent = 16,
  ramUsedMb = 5120,
  ramTotalMb = 32000,
  swapUsedMb = 300,
  swapTotalMb = 10000,
}

local board = desktop.board({ stats = stats })
assert(board.type == "column", "board is a column")
assert(board.props.width == 500 and board.props.height == 306, "board keeps the sysmon footprint")
assert(board.props.fill == "surface_variant", "board is raised walnut")
assert(board.props.border == "outline" and board.props.borderWidth == 1, "board has a hairline")
assert(board.props.radius == 6, "board radius")

local caption = stub.find(board, function(node)
  return node.props ~= nil and node.props.key == "instrument-caption"
end)
assert(caption ~= nil, "caption rail present")
assert(caption.children[1].props.text == "INSTRUMENT PANEL", "caption in small caps")
assert(caption.children[2].props.text == "No. 1988354527", "accession number")

assert(stub.count(board, "box") >= 64, "four 16-segment meters plus rules")
assert(stub.count(board, "progress") == 0, "segmented gauge, not a bar")

local gpu = stub.find(board, function(node)
  return node.props ~= nil and node.props.key == "instrument-gpu"
end)
assert(gpu ~= nil, "gpu instrument")
assert(stub.find(gpu, function(node)
  return node.type == "label" and node.props.text == "GPU LOAD"
end) ~= nil, "name in small caps")
assert(stub.find(gpu, function(node)
  return node.type == "label" and node.props.text == "10%"
end) ~= nil, "value in brass is the live percentage")
assert(stub.find(gpu, function(node)
  return node.type == "label" and node.props.text == "57°C"
end) ~= nil, "secondary readout in patina")

local vram = stub.find(board, function(node)
  return node.props ~= nil and node.props.key == "instrument-vram"
end)
assert(vram ~= nil, "vram instrument")
assert(stub.find(vram, function(node)
  return node.type == "label" and node.props.text == "11%"
end) ~= nil, "vram percentage")
assert(stub.find(vram, function(node)
  return node.type == "label" and node.props.text == "0.9G"
end) ~= nil, "vram used in GiB")

local ram = stub.find(board, function(node)
  return node.props ~= nil and node.props.key == "instrument-ram"
end)
assert(stub.find(ram, function(node)
  return node.type == "label" and node.props.text == "swap 3%"
end) ~= nil, "swap secondary")

-- Segment keys are unique across the four gauges (the reconciler matches on
-- key), and each gauge is 16 segments.
local keys = {}
for _, node in ipairs(stub.findAll(board, function(node)
  return node.props ~= nil and node.props.key ~= nil and string.find(node.props.key, "-seg-", 1, true) ~= nil
end)) do
  assert(keys[node.props.key] == nil, "duplicate segment key " .. node.props.key)
  keys[node.props.key] = true
end
local segmentCount = 0
for _ in pairs(keys) do
  segmentCount = segmentCount + 1
end
assert(segmentCount == 64, "four meters of sixteen segments")

-- Absent probes stay absent: an em dash, not a fabricated zero.
local empty = desktop.board({ stats = {} })
assert(stub.find(empty, function(node)
  return node.type == "label" and node.props.text == "no probe"
end) ~= nil, "missing vram names the probe")
assert(stub.find(empty, function(node)
  return node.type == "label" and node.props.text == "—"
end) ~= nil, "missing values use the em dash")

-- ── the clock placard ─────────────────────────────────────────────────────

local clock = desktop.clock({ time = "15:25", date = "Wednesday 21 October", second = 30 })
assert(clock.type == "column", "clock is a column")
assert(clock.props.width == 464 and clock.props.height == 96, "clock placard geometry")
assert(clock.props.fill == "surface_variant", "clock is walnut")
local timeLabel = stub.find(clock, function(node)
  return node.props ~= nil and node.props.key == "clock-time"
end)
assert(timeLabel.props.text == "15:25", "time")
local dateLabel = stub.find(clock, function(node)
  return node.props ~= nil and node.props.key == "clock-date"
end)
assert(dateLabel.props.text == "WEDNESDAY 21 OCTOBER", "date in small caps")
local meter = stub.find(clock, function(node)
  return node.props ~= nil and node.props.key == "clock-meter"
end)
assert(meter ~= nil and #meter.children == 20, "twenty-second segments")
local lit = 0
for _, segment in ipairs(meter.children) do
  if segment.props.fill == "primary" then
    lit = lit + 1
  end
end
assert(lit == 10, "half a minute lights half the meter")

-- ── the month plate ───────────────────────────────────────────────────────

local month = desktop.month({ offset = 0 })
assert(month.type == "column", "month is a column")
assert(month.props.width == 620 and month.props.height == 420, "month plate geometry")
assert(month.props.fill == "surface_variant", "month plate is walnut")
local weekdays = stub.find(month, function(node)
  return node.props ~= nil and node.props.key == "month-weekdays"
end)
assert(weekdays ~= nil and #weekdays.children == 7, "seven weekday columns")

local weeks = stub.find(month, function(node)
  return node.props ~= nil and node.props.key == "month-weeks"
end)
assert(weeks ~= nil, "week grid")
local inMonth = 0
for _, week in ipairs(weeks.children) do
  assert(#week.children == 7, "whole weeks only")
  for _, cell in ipairs(week.children) do
    local key = cell.props.key
    if string.find(key, "month-day-", 1, true) == 1 and not string.find(key, "lead-", 1, true) and not string.find(key, "trail-", 1, true) then
      inMonth = inMonth + 1
    end
  end
end
local cells = desktop.monthCells(0)
local expected = tonumber(os.date("%d", os.time({
  year = cells.today.year,
  month = cells.today.month + 1,
  day = 0,
  hour = 12,
})))
assert(inMonth == expected, "the grid holds the whole month")

local wall = stub.find(month, function(node)
  return node.props ~= nil and node.props.key == "month-wall-text"
end)
assert(wall ~= nil and string.find(wall.props.text, "no events scheduled", 1, true) ~= nil, "wall text names the calendar state")

-- The previous-month control renders and carries its callback.
local prev = stub.find(month, function(node)
  return node.props ~= nil and node.props.key == "month-prev"
end)
assert(prev ~= nil and prev.type == "button", "previous-month button")

-- ── the entry scripts ─────────────────────────────────────────────────────
-- The three files below are concatenated by the runner; their top-level
-- render() runs against the stub and the last tree is inspected here.
