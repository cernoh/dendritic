--!nonstrict
-- Component-library tests (PLAN 2.7).
--
-- Assembled and run by ../../../tests/run-museum-tests.sh: the Luau CLI gives
-- every required module its own environment, so the stub host, the library and
-- the driver are concatenated into one chunk (stub.luau is wrapped in a
-- function). Assertions are on the rendered ui.* tree, never on pixels.


-- ── formatting ────────────────────────────────────────────────────────────

assert(museum.roman(1) == "I", "roman 1")
assert(museum.roman(4) == "IV", "roman 4")
assert(museum.roman(9) == "IX", "roman 9")
assert(museum.pct(9.4) == "9%", "pct rounds")
assert(museum.pct(nil) == "—", "pct absent")
assert(museum.temp(53) == "53°C", "temp")
assert(museum.temp(nil) == "—", "temp absent")
assert(museum.megabytes(6861) == "6.7G", "megabytes")
assert(museum.megabytes(512) == "512M", "megabytes small")

assert(museum.truncate("abc", 5) == "abc", "short text untouched")
assert(museum.truncate("abcdefgh", 5) == "ab…", "long text truncated to the byte cap")
assert(#museum.truncate(string.rep("x", 400), 260) <= 260, "truncation stays inside the cap")
assert(museum.truncate("abcdef", 1) == "", "one-byte cap cannot hold ellipsis")

-- ── materials ─────────────────────────────────────────────────────────────

assert(museum.t.brass == "primary", "brass is a role")
assert(museum.t.paper == "on_surface", "paper is the inverted surface")
assert(museum.t.paperInk == "surface", "paper ink is the surface role")
assert(museum.t.brassLt == "#e2c08a", "brass-lt resolves from the palette document")
assert(museum.t.paper3 == "#c8b58d" and museum.t.patina == "#7d9a8e", "the three museum roles load as one set")
assert(#museum.museumKeys == 3, "three palette keys")
assert(#museum.hexExceptions == 3, "exactly three hex exceptions")

-- ── Plate ─────────────────────────────────────────────────────────────────

local plate = museum.plate({
  id = "machine",
  caption = "Machine",
  body = museum.ledger({
    orientation = "row",
    cells = { { key = "ram", value = "6.7G" }, { key = "cpu", value = "9%" } },
  }),
})
assert(plate.type == "column", "plate is a column")
assert(plate.props.width == museum.width.machine, "plate takes its cap from the table")
assert(plate.props.fill == "surface_variant", "plate body is raised walnut")
assert(plate.props.border == "outline", "plate border is the hairline role")
assert(plate.props.borderWidth == 1, "plate border is 1 px")
assert(plate.props.radius == 4, "plate radius")
assert(#plate.children == 2, "caption + body")
assert(plate.children[1].props.text == "Machine", "caption row")
assert(plate.children[1].props.maxWidth < plate.props.width, "caption respects inner width")
assert(plate.children[2].type == "row", "compact ledger is one row")

-- Plate caps are library-owned: a caller cannot widen one.
local wide = museum.plate({ id = "machine", width = 999, caption = "x" })
assert(wide.props.width == museum.width.machine, "instance width is ignored")

-- ── Ledger (column form has the solid leader) ─────────────────────────────

local ledger = museum.ledger({
  cells = { { key = "Maker", value = "Noctalia" }, { key = "Medium", value = "Luau" } },
})
assert(ledger.type == "column", "column ledger")
assert(#ledger.children == 2, "two rows")
local firstRow = ledger.children[1]
assert(firstRow.type == "row", "ledger row")
assert(firstRow.props.justify == "space_between", "ledger row spreads")
local separator = stub.find(firstRow, function(node)
  return node.type == "separator"
end)
assert(separator ~= nil, "ledger uses a solid separator as its leader")
assert(separator.props.thickness == 1, "leader is 1 px")
assert(separator.props.color == "outline/0.5", "leader is a translucent hairline")

-- ── Meter: bar and segmented gauge ────────────────────────────────────────

local bar = museum.meter({ value = 0.53, width = 80 })
assert(bar.type == "progress", "bar meter is ui.progress")
assert(bar.props.fill == "primary", "bar meter is brass")
assert(math.abs(bar.props.progress - 0.53) < 0.001, "bar meter value")

local gauge = museum.gauge({ value = 0.63, segments = 10, width = 100 })
assert(gauge.type == "row", "gauge is a row")
assert(#gauge.children == 10, "ten segments")
local filled = 0
for _, segment in ipairs(gauge.children) do
  assert(segment.type == "box", "segment is a box")
  assert(segment.props.flexGrow == 1, "segment flexes")
  if segment.props.fill == "primary" then
    filled = filled + 1
  else
    assert(segment.props.fill == "outline/0.25", "empty segment is dim outline")
  end
end
assert(filled == 6, "63% rounds to six of ten segments across")

local clamped = museum.gauge({ value = 4, segments = 4 })
assert(#clamped.children == 4, "gauge clamps high")
local zero = museum.gauge({ value = -1, segments = 4 })
for _, segment in ipairs(zero.children) do
  assert(segment.props.fill == "outline/0.25", "negative value fills nothing")
end

-- ── Lever: buttons, never a sliding switch ────────────────────────────────

local lever = museum.lever({
  value = "on",
  positions = {
    { value = "on", label = "ON", onClick = function() end },
    { value = "off", label = "OFF", onClick = function() end },
  },
})
assert(lever.type == "row", "lever is a row")
assert(#lever.children == 2, "one button per position")
assert(lever.children[1].props.variant == "primary", "selected position is brass")
assert(lever.children[2].props.variant == "ghost", "other position is quiet")
assert(stub.count(lever, "toggle") == 0, "no native toggle")

-- ── Slip: paper record, stamped ───────────────────────────────────────────

local slip = museum.slip({
  caption = "Now viewing",
  title = "noctalia msg screens ~",
  stamp = "RECEIVED",
})
assert(slip.props.fill == "on_surface", "slip is an inverted surface")
assert(slip.children[1].props.color == "surface", "slip caption ink")
assert(slip.children[2].props.color == "surface", "slip title ink")
for _, color in ipairs(stub.colors(slip)) do
  assert(string.sub(color, 1, 1) ~= "#", "slip has no hex outside the exceptions")
end
local stamp = stub.find(slip, function(node)
  return node.type == "box" and node.props.borderWidth == 2
end)
assert(stamp ~= nil, "stamp is a solid-bordered box")
assert(stamp.props.width == 64 and stamp.props.height == 16, "stamp is axis-aligned")
assert(stamp.props.radius == 1, "stamp is not a pill")

-- ── width discipline ──────────────────────────────────────────────────────

local budget = museum.widthBudget()
assert(
  budget <= museum.barMaxWidth,
  string.format("worst-case bar budget %d exceeds %d", budget, museum.barMaxWidth)
)
assert(budget > 1200, "budget sanity: the bar is populated")
assert(museum.width.halls < 220, "nine halls stay a small rail")
assert(museum.width.label < 300, "wall label is width-capped")

-- Every hex emitted by any component is one of the three exceptions.
local everything = ui.column({}, {
  plate,
  ledger,
  bar,
  gauge,
  lever,
  slip,
  museum.meter({ value = 0.5 }),
  museum.gauge({ value = 0.5 }),
  museum.plate({ id = "thermal", caption = "Thermal" }),
})
for _, color in ipairs(stub.colors(everything)) do
  if string.sub(color, 1, 1) == "#" then
    local allowed = false
    for _, exception in ipairs(museum.hexExceptions) do
      if color == exception then
        allowed = true
      end
    end
    assert(allowed, "unexpected hex " .. color)
  end
end

print(string.format("museum.luau: ok (%d px worst-case bar of 1920)", budget))
