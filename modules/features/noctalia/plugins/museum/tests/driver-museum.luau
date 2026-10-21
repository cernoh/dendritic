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
assert(museum.truncate("éééééé", 5) == "é…", "truncation never splits a UTF-8 sequence")
assert(#museum.truncate("éééééé", 5) == 5, "the ellipsis stays inside the byte cap")
assert(museum.truncate(nil, 10) == "", "nil text is empty")
assert(museum.roman(10) == "X", "roman ten")
assert(museum.roman(11) == "11", "beyond ten falls back to digits")
assert(museum.roman(0) == "0", "roman zero")
assert(museum.megabytes(1024) == "1.0G", "megabytes crosses to gigabytes")
assert(museum.megabytes(0) == "0M", "megabytes zero")
assert(museum.pct(-1) == "-1%", "pct keeps a negative")
assert(museum.number(nil, "%.0f") == "—", "number absent is a dash")

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
assert(plate.props.key == "plate-machine", "the plate keys its id")

local footed = museum.plate({
  id = "machine",
  caption = "Machine",
  body = museum.value("body"),
  footer = museum.caption("foot"),
})
assert(#footed.children == 3, "caption + body + footer")
assert(footed.children[3].props.text == "foot", "footer follows the body")

local captionOnly = museum.plate({ id = "machine", caption = "Machine" })
assert(#captionOnly.children == 1, "a plate without a body is a titled rule")

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

local column = museum.ledger({
  cells = { { key = "Maker", value = "Noctalia", color = "error" } },
  keyWidth = 40,
  gap = 2,
})
assert(column.props.gap == 2, "ledger row gap")
assert(column.children[1].children[1].props.maxWidth == 40, "ledger key width")
assert(column.children[1].children[3].props.color == "error", "ledger value color")
assert(#museum.ledger({}).children == 0, "an empty ledger is empty")

-- ── Meter: bar and segmented gauge ────────────────────────────────────────

local bar = museum.meter({ value = 0.53, width = 80 })
assert(bar.type == "progress", "bar meter is ui.progress")
assert(bar.props.fill == "primary", "bar meter is brass")
assert(math.abs(bar.props.progress - 0.53) < 0.001, "bar meter value")

local custom = museum.meter({
  value = 0.25,
  fill = "tertiary",
  track = "surface_variant",
  width = 50,
  height = 9,
})
assert(custom.props.fill == "tertiary" and custom.props.track == "surface_variant", "meter materials")
assert(custom.props.width == 50 and custom.props.height == 9, "meter geometry")
assert(math.abs(custom.props.progress - 0.25) < 0.001, "meter clamps into 0..1")
assert(museum.meter({ value = 2 }).props.progress == 1, "meter clamps high")
assert(museum.meter({ value = -1 }).props.progress == 0, "meter clamps low")

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

local prefixed = museum.gauge({ value = 0.5, segments = 8, keyPrefix = "drive-", height = 5 })
assert(#prefixed.children == 8, "gauge segment count")
assert(prefixed.children[1].props.key == "drive-1", "gauge key prefix")
assert(prefixed.children[1].props.height == 5, "gauge segment height")

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

local three = museum.lever({
  value = "b",
  itemWidth = 30,
  positions = {
    { value = "a", label = "A" },
    { value = "b", label = "B" },
    { value = "c", label = "C" },
  },
})
assert(#three.children == 3, "three-position throw")
assert(three.children[2].props.selected == true, "the middle position is seated")
assert(three.children[2].props.variant == "primary", "the seated position is brass")
assert(three.children[1].props.selected == false, "an unseated position is quiet")
assert(three.children[1].props.width == 30, "item width reaches each throw")
assert(#museum.lever({ value = "x" }).children == 0, "a lever with no positions is empty")

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

local full = museum.slip({
  caption = "c",
  title = "t",
  footer = "f",
  stamp = "S",
  width = 200,
  stampColor = "error",
})
assert(#full.children == 4, "caption + title + footer + stamp")
assert(full.props.width == 200, "slip width")
assert(full.children[3].props.text == "f", "slip footer")
assert(full.children[4].props.border == "error", "stamp ink")

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

-- ── token resolution: every host answer, not just the happy path ──────────
-- The module resolves at load. Re-run it under each answer the shell can give:
-- light mode, a non-custom palette source, a document without `museum`, and a
-- document with a malformed value. The role seed must survive every one.
local realGetSetting = stub.noctalia.getSetting
local realIsDark = stub.noctalia.isDarkMode
local palettePath = "/home/tester/.config/noctalia/palettes/sepia.json"
local realPalette = stub.rec.files[palettePath]

stub.noctalia.isDarkMode = function()
  return false
end
museum.resolveMaterials()
assert(museum.t.brassLt == "#8a6a3f", "light variant brass-lt")
assert(museum.t.paper3 == "#8a7a5f", "light variant paper3")
assert(museum.t.patina == "#4f6a60", "light variant patina")

stub.noctalia.isDarkMode = realIsDark
stub.noctalia.getSetting = function(path)
  if path == "theme.source" then
    return "builtin"
  end
  return nil
end
museum.t.brassLt = "primary"
museum.t.paper3 = "outline"
museum.t.patina = "tertiary"
museum.resolveMaterials()
assert(museum.t.brassLt == "primary", "a non-custom theme keeps the role seed")
assert(museum.t.patina == "tertiary", "the patina seed survives")

stub.noctalia.getSetting = realGetSetting
stub.rec.files[palettePath] = '{"dark":{"mPrimary":"#123456"}}'
museum.resolveMaterials()
assert(museum.t.brassLt == "primary", "a palette without a museum object keeps the seed")

stub.rec.files[palettePath] = '{"dark":{"museum":{"brassLt":"brass","paper3":"#12345","patina":"#7d9a8e"}}}'
museum.resolveMaterials()
assert(museum.t.brassLt == "primary", "a non-hex brass-lt is ignored")
assert(museum.t.paper3 == "outline", "a short hex is ignored")
assert(museum.t.patina == "#7d9a8e", "a valid value in a mixed document still lands")

stub.rec.files[palettePath] = realPalette
museum.resolveMaterials()
assert(
  museum.t.brassLt == "#e2c08a" and museum.t.paper3 == "#c8b58d" and museum.t.patina == "#7d9a8e",
  "the dark palette restores"
)

-- ── every component against the host's reconciler contract ────────────────
-- stub.validate rejects an unknown control, an unknown prop (a loud skip in
-- the shell), a box with children (dropped by the shell), and a color that is
-- neither a role nor a hex.
stub.validate(ui.column({}, {
  plate,
  captionOnly,
  footed,
  ledger,
  column,
  bar,
  custom,
  gauge,
  prefixed,
  lever,
  three,
  slip,
  full,
  everything,
}))

print(string.format("museum.luau: ok (%d px worst-case bar of 1920)", budget))
