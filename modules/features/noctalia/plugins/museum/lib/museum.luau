--!nonstrict
-- The museum component library (PLAN.md phase 2).
--
-- Five components carry every surface — Plate, Ledger, Meter, Lever, Slip —
-- plus the shared material tokens, the number formatters, and the single
-- width-discipline table (PLAN 3.8: caps live here, never per instance).
--
-- Tokens are noctalia M3 palette roles, so a palette change reskins the whole
-- museum. The three materials DESIGN.md §3 names as having no role stand-in
-- (brass-lt, paper3, patina) are resolved from the shell's own palette document
-- at `dark.museum` — the contract `features/scheme` established in Phase 1 —
-- so this file carries no hex of its own. Each is seeded with the nearest role
-- and replaced at load; a shell on another palette source degrades to the role
-- rather than failing. tests/museum.luau asserts the resolved values.

local M = {}

M.t = {
  brass = "primary", -- the accent; one per surface
  brassInk = "on_primary", -- text on brass
  brassDk = "outline", -- hairlines, plate borders
  walnut = "surface", -- panel body
  walnut2 = "surface_variant", -- raised plate body
  walnut3 = "hover", -- inset / pressed
  bone = "on_surface", -- primary text
  paperDim = "on_surface_variant", -- secondary text
  inkRed = "error", -- RECEIVED stamp
  inkGreen = "tertiary", -- APPROVED stamp
  paper = "on_surface", -- the slip is an inverted surface
  paperInk = "surface", -- text on paper
  -- Replaced at load from the palette document's `museum` object.
  brassLt = "primary",
  paper3 = "outline",
  patina = "tertiary",
}

-- The palette keys resolved from the shell, and the values they resolved to.
M.museumKeys = { "brassLt", "paper3", "patina" }
M.hexExceptions = {}

local function resolveMuseumMaterials()
  if noctalia == nil or noctalia.getSetting == nil then
    return
  end
  if noctalia.getSetting("theme.source") ~= "custom" then
    return
  end
  local name = noctalia.getSetting("theme.custom_palette")
  if type(name) ~= "string" or name == "" then
    return
  end

  local path = noctalia.expandPath("~/.config/noctalia/palettes/" .. name .. ".json")
  local raw = noctalia.readFile(path)
  local decoded = raw ~= nil and noctalia.json.decode(raw) or nil
  if decoded == nil then
    return
  end

  local variant = decoded.dark
  if not noctalia.isDarkMode() and decoded.light ~= nil then
    variant = decoded.light
  end
  local museum = variant ~= nil and variant.museum or nil
  if museum == nil then
    return
  end

  for _, key in ipairs(M.museumKeys) do
    local value = museum[key]
    if type(value) == "string" and string.match(value, "^#%x%x%x%x%x%x$") ~= nil then
      M.t[key] = value
    end
  end
end

M.resolveMaterials = resolveMuseumMaterials
resolveMuseumMaterials()

for _, key in ipairs(M.museumKeys) do
  table.insert(M.hexExceptions, M.t[key])
end

-- ── Width discipline ───────────────────────────────────────────────────────
-- The one source of truth for 1920-px fit. A component reads its own cap by
-- name; no widget passes a width. The values were chosen from the artifact
-- (museum-reskin-before-after.html §01) with the widest realistic content:
-- nine hall plates, a 40-character wall-label title, three machine cells.
M.width = {
  launcher = 32,
  halls = 204, -- 9 plates × 20 + 8 gaps × 2 + 16 padding/border
  hallPlate = 20,
  label = 268,
  machine = 176,
  clock = 104,
  thermal = 158,
  gauge = 132,
  exhibit = 168,
  tray = 96,
  seal = 26,
  audio = 124,
  power = 30,
  platePadding = 12,
}

M.barMaxWidth = 1920
M.barMargins = 200 -- [bar.main] margin_ends = 100, both sides
M.barSpacing = 8 -- [bar.main] widget_spacing

-- Worst case: every bar widget present, nine halls, at its cap.
function M.widthBudget()
  local caps = {
    "launcher",
    "halls",
    "label",
    "machine",
    "clock",
    "thermal",
    "gauge",
    "exhibit",
    "tray",
    "seal",
    "audio",
    "power",
  }
  local total = M.barMargins
  for _, name in ipairs(caps) do
    total = total + M.width[name]
  end
  total = total + (#caps - 1) * M.barSpacing
  return total
end

-- ── Numbers and text ───────────────────────────────────────────────────────

local DASH = "—"

function M.number(value, pattern)
  if value == nil then
    return DASH
  end
  local ok, text = pcall(string.format, pattern, value)
  if not ok then
    return DASH
  end
  return text
end

function M.pct(value)
  return M.number(value, "%.0f%%")
end

function M.temp(value)
  return M.number(value, "%.0f°C")
end

function M.megabytes(value)
  if value == nil then
    return DASH
  end
  if value >= 1024 then
    return string.format("%.1fG", value / 1024)
  end
  return string.format("%.0fM", value)
end

-- Roman numeral for a hall plate. Mango tags run 1..9; anything above falls
-- back to its digits rather than inventing a convention.
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function M.roman(index)
  return ROMAN[index] or tostring(index)
end

-- Byte-safe truncation: never cut a UTF-8 continuation byte in half, and the
-- result (ellipsis included) never exceeds maxLength bytes. The bar also caps
-- the label's pixels, so this is the content bound, not the visual one.
function M.truncate(text, maxLength)
  if text == nil then
    return ""
  end
  if maxLength == nil or maxLength <= 0 or #text <= maxLength then
    return text
  end
  local cut = maxLength - 3 -- "…" is three bytes in UTF-8
  while cut > 0 do
    local byte = string.byte(text, cut + 1)
    if byte == nil or byte < 0x80 or byte >= 0xC0 then
      break
    end
    cut = cut - 1
  end
  if cut <= 0 then
    return ""
  end
  return string.sub(text, 1, cut) .. "…"
end

-- ── Primitives ─────────────────────────────────────────────────────────────

function M.caption(text, opts)
  opts = opts or {}
  return ui.label({
    text = text,
    fontSize = opts.fontSize or 9,
    fontWeight = opts.fontWeight or "bold",
    color = opts.color or M.t.paperDim,
    maxWidth = opts.maxWidth,
    maxLines = 1,
  })
end

function M.value(text, opts)
  opts = opts or {}
  return ui.label({
    text = text,
    fontSize = opts.fontSize or 13,
    fontWeight = opts.fontWeight or "semibold",
    color = opts.color or M.t.bone,
    fontFamily = opts.fontFamily,
    maxWidth = opts.maxWidth,
    maxLines = 1,
  })
end

function M.keyValue(key, value, opts)
  opts = opts or {}
  return ui.row({ gap = 3, align = "center" }, {
    M.caption(key, { fontSize = opts.keySize or 9 }),
    M.value(value, { fontSize = opts.valueSize or 13, color = opts.valueColor }),
  })
end

-- Plate: a titled field. `id` picks the width cap; never pass a width.
function M.plate(cfg)
  local width = M.width[cfg.id] or cfg.width or M.width.machine
  local inner = width - 2 - M.width.platePadding
  local header = M.caption(cfg.caption, {
    maxWidth = inner,
    color = cfg.captionColor or M.t.paperDim,
  })
  local children = { header }
  if cfg.body ~= nil then
    table.insert(children, cfg.body)
  end
  if cfg.footer ~= nil then
    table.insert(children, cfg.footer)
  end
  return ui.column({
    key = cfg.key or ("plate-" .. tostring(cfg.id)),
    width = width,
    gap = 1,
    paddingH = 6,
    paddingV = 3,
    fill = cfg.fill or M.t.walnut2,
    radius = 4,
    border = cfg.border or M.t.brassDk,
    borderWidth = 1,
    align = "start",
  }, children)
end

-- Ledger: ruled rows of key → value. `orientation = "row"` is the compact bar
-- form (one line of cells); the default column is the panel form with solid
-- 1 px leaders, since dotted leaders need Tier B.
function M.ledger(cfg)
  local cells = cfg.cells or {}
  if cfg.orientation == "row" then
    local row = {}
    for index, cell in ipairs(cells) do
      if index > 1 then
        table.insert(row, ui.box({ width = cfg.gap or 6 }))
      end
      table.insert(row, M.keyValue(cell.key, cell.value, {
        keySize = cfg.keySize,
        valueSize = cfg.valueSize,
        valueColor = cell.color,
      }))
    end
    return ui.row({ gap = 0, align = "center" }, row)
  end

  local rows = {}
  for _, cell in ipairs(cells) do
    table.insert(rows, ui.row({
      key = "ledger-" .. tostring(cell.key),
      gap = 6,
      align = "center",
      justify = "space_between",
    }, {
      M.caption(cell.key, { maxWidth = cfg.keyWidth or 96 }),
      ui.separator({ thickness = 1, color = M.t.brassDk .. "/0.5", flexGrow = 1 }),
      M.value(cell.value, { color = cell.color }),
    }))
  end
  return ui.column({ gap = cfg.gap or 4 }, rows)
end

-- Meter: the filled-bar form.
function M.meter(cfg)
  cfg = cfg or {}
  local value = math.clamp(cfg.value or 0, 0, 1)
  return ui.progress({
    progress = value,
    fill = cfg.fill or M.t.brass,
    track = cfg.track or "surface",
    radius = 2,
    width = cfg.width or M.width.gauge,
    height = cfg.height or 6,
  })
end

-- Meter: the segmented gauge. The default for anything brass, because a knob
-- cannot be placed at an arbitrary x in Tier A.
function M.gauge(cfg)
  cfg = cfg or {}
  local value = math.clamp(cfg.value or 0, 0, 1)
  local segments = cfg.segments or 10
  local filled = math.floor(value * segments + 0.5)
  local prefix = cfg.keyPrefix or "seg-"
  local boxes = {}
  for index = 1, segments do
    table.insert(boxes, ui.box({
      key = prefix .. index,
      flexGrow = 1,
      height = cfg.height or 8,
      radius = 1,
      fill = index <= filled and (cfg.fill or M.t.brass) or (M.t.brassDk .. "/0.25"),
    }))
  end
  return ui.row({ gap = 2, align = "center", width = cfg.width or M.width.gauge }, boxes)
end

-- Lever: a row of buttons, one per position. No sliding switch in Tier A.
function M.lever(cfg)
  local buttons = {}
  for _, position in ipairs(cfg.positions or {}) do
    local selected = position.value == cfg.value
    table.insert(buttons, ui.button({
      key = "lever-" .. tostring(position.value),
      text = position.label,
      variant = selected and "primary" or "ghost",
      selected = selected,
      fontSize = cfg.fontSize or 12,
      width = cfg.itemWidth,
      onClick = position.onClick,
    }))
  end
  return ui.row({ gap = 2, align = "center" }, buttons)
end

-- Slip: a paper record. The stamp is an axis-aligned solid-bordered box —
-- rotation and dashed borders are Tier B.
function M.slip(cfg)
  local width = cfg.width or M.width.label
  local inner = width - 2 - M.width.platePadding
  local children = {
    M.caption(cfg.caption, { color = M.t.paperInk, maxWidth = inner }),
    M.value(cfg.title, {
      color = M.t.paperInk,
      fontSize = cfg.fontSize or 13,
      fontFamily = cfg.fontFamily,
      maxWidth = inner,
    }),
  }
  if cfg.footer ~= nil then
    table.insert(children, M.caption(cfg.footer, { color = M.t.paperInk, maxWidth = inner }))
  end
  if cfg.stamp ~= nil then
    table.insert(children, ui.box({
      width = 64,
      height = 16,
      radius = 1,
      border = cfg.stampColor or M.t.inkRed,
      borderWidth = 2,
    }))
  end
  return ui.column({
    key = cfg.key or "slip",
    width = width,
    gap = 1,
    paddingH = 6,
    paddingV = 3,
    fill = M.t.paper,
    radius = 2,
    align = "start",
  }, children)
end

return M
