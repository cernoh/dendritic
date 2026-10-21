--!nonstrict
-- Drawer-scale geometry for the five museum components.
--
-- `lib/museum.luau` is the bar's component library: every plate there takes a
-- width from `M.width`, because the bar has to fit 1920 px with every widget
-- present (PLAN 3.8). The drawer is the opposite problem — one wide surface
-- whose plates flex to fill it — so this module composes the *same* primitives
-- (`museum.caption`, `museum.value`, `museum.gauge`, `museum.meter`,
-- `museum.lever`, the tokens and the formatters) at panel scale instead of
-- passing a bar width.
--
-- Nothing here invents a sixth component. Plate, Ledger, Meter, Lever and Slip
-- keep the DESIGN §5 shapes; what changes is padding, flex, and the slip's
-- stamp, which carries its word in the drawer (the bar's stamp is a mark, the
-- drawer's is a record). The three no-role hexes stay in one place: this file
-- owns none, it reads `museum.t`.
--
-- tests/panel.luau asserts every drawer component against the stub host.

local museum = require("./museum.luau")

local M = museum.t
local D = {}

D.t = M
D.hexExceptions = museum.hexExceptions

local function upper(text)
  return string.upper(tostring(text))
end

function D.alpha(role, value)
  return tostring(role) .. "/" .. tostring(value)
end

-- Plate — a titled field holding content.
function D.plate(cfg, children)
  cfg = cfg or {}
  local kids = {}
  if cfg.caption ~= nil or cfg.note ~= nil then
    local cells = {}
    if cfg.caption ~= nil then
      table.insert(cells, ui.column({ flexGrow = 1, align = "start" }, {
        museum.caption(upper(cfg.caption), {
          fontSize = 9,
          color = cfg.captionColor,
          maxWidth = cfg.captionWidth,
        }),
      }))
    end
    if cfg.note ~= nil then
      table.insert(cells, ui.label({
        text = upper(cfg.note),
        fontSize = 9,
        fontFamily = "monospace",
        color = cfg.noteColor or M.paperDim,
        maxLines = 1,
      }))
    end
    table.insert(kids, ui.row({
      key = cfg.key and (cfg.key .. "-caption") or nil,
      justify = "space_between",
      align = "center",
      gap = 8,
    }, cells))
  end
  for _, child in ipairs(children or {}) do
    table.insert(kids, child)
  end
  return ui.column({
    key = cfg.key,
    fill = cfg.fill or M.walnut2,
    radius = 4,
    border = cfg.border or M.brassDk,
    borderWidth = 1,
    padding = cfg.padding or 13,
    gap = cfg.gap or 9,
    -- Explicit: a retained control keeps the last opacity it was given.
    opacity = cfg.opacity or 1,
    flexGrow = cfg.flexGrow,
    width = cfg.width,
    minHeight = cfg.minHeight,
  }, kids)
end

-- Ledger — ruled rows of key → leader → value.
--
-- The leader is the same 1 px `ui.separator` the bar's ledger uses, so both
-- surfaces share one rule. `cell.gauge` adds a segmented meter before the
-- value (a mount's fill, a network's signal); `cell.onClick` makes the whole
-- row the hit target, which is how a network is joined from the registry.
function D.ledger(cfg)
  cfg = cfg or {}
  local rows = {}
  for index, cell in ipairs(cfg.cells or {}) do
    local cells = {
      -- Labels are small caps; a record's own name (a mount, an SSID, a
      -- device) keeps its case, because a name is data and not a caption.
      museum.caption(cell.rawKey and cell.key or upper(cell.key), {
        fontSize = cfg.keySize or 9,
        maxWidth = cfg.keyWidth or 170,
      }),
      -- The leader is a 1 px box. `ui.separator` looks like the obvious
      -- primitive, but it always paints a centre-peaked fade that a plugin
      -- cannot turn off (AGENTS.md 0.3); a box is a true hairline.
      ui.box({ height = 1, flexGrow = 1, fill = D.alpha(M.brassDk, 0.5) }),
    }
    if cell.gauge ~= nil then
      table.insert(cells, museum.gauge({
        value = cell.gauge,
        segments = cell.segments or cfg.segments or 8,
        width = cell.gaugeWidth or 64,
        height = 6,
        fill = cell.gaugeColor,
      }))
    end
    table.insert(cells, museum.value(cell.value, {
      color = cell.color or M.brassLt,
      fontFamily = "monospace",
      fontSize = cfg.valueSize or 12,
    }))
    table.insert(rows, ui.row({
      key = cell.nodeKey or (cfg.key and (cfg.key .. "-row-" .. tostring(index)) or nil),
      gap = 8,
      align = "center",
      justify = "space_between",
      paddingV = cfg.rowPaddingV or 5,
      onClick = cell.onClick,
      tooltip = cell.tooltip,
    }, cells))
  end
  return ui.column({ key = cfg.key, gap = cfg.gap or 0, flexGrow = cfg.flexGrow }, rows)
end

-- Meter — the segmented gauge, the default for anything brass.
function D.meter(cfg)
  cfg = cfg or {}
  return museum.gauge({
    value = cfg.value,
    segments = cfg.segments or 10,
    width = cfg.width or 96,
    height = cfg.height or 6,
    fill = cfg.fill,
  })
end

-- Meter.bar — the solid form, for a full-width line (media position).
function D.bar(cfg)
  cfg = cfg or {}
  local grow = 1
  if cfg.flexGrow == false then
    grow = nil
  end
  return ui.progress({
    key = cfg.key,
    progress = math.clamp(cfg.value or 0, 0, 1),
    fill = cfg.fill or M.brass,
    track = cfg.track or "surface",
    radius = 2,
    height = cfg.height or 8,
    flexGrow = grow,
  })
end

-- Lever — a row of buttons, one per position.
function D.lever(cfg)
  cfg = cfg or {}
  local positions = {}
  for index, label in ipairs(cfg.labels or {}) do
    positions[#positions + 1] = {
      value = index,
      label = upper(label),
      onClick = cfg.onSelect and function()
        cfg.onSelect(index)
      end or nil,
    }
  end
  return museum.lever({
    positions = positions,
    value = cfg.index,
    fontSize = cfg.fontSize or 10,
    itemWidth = cfg.itemWidth,
  })
end

-- Lever.two — a boolean as ON / OFF.
function D.toggle(cfg)
  cfg = cfg or {}
  return D.lever({
    labels = { "On", "Off" },
    index = cfg.on and 1 or 2,
    fontSize = cfg.fontSize or 9,
    onSelect = cfg.onSelect and function(index)
      cfg.onSelect(index == 1)
    end or nil,
  })
end

-- IndexTabs — brass index tabs on a drawer edge.
function D.tabs(cfg)
  cfg = cfg or {}
  local kids = {}
  for index, label in ipairs(cfg.labels or {}) do
    local on = index == cfg.index
    kids[#kids + 1] = ui.row({
      key = cfg.key and (cfg.key .. "-tab-" .. tostring(index)) or nil,
      paddingH = 11,
      paddingV = 7,
      radius = 3,
      fill = on and M.brass or M.walnut3,
      onClick = cfg.onSelect and function()
        cfg.onSelect(index)
      end or nil,
    }, {
      ui.label({
        text = upper(label),
        fontSize = 9,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = on and M.brassInk or M.paperDim,
      }),
    })
  end
  return ui.row({ key = cfg.key, gap = 4, align = "stretch" }, kids)
end

-- Slip — a paper record. The slip is an inverted surface; the stamp is an
-- axis-aligned solid-bordered row carrying its word, because no rotation and
-- no dashed border exist in Tier A.
function D.slip(cfg)
  cfg = cfg or {}
  local tone = cfg.tone == "green" and M.inkGreen or M.inkRed
  local heading = {}
  if cfg.caption ~= nil then
    table.insert(heading, museum.caption(upper(cfg.caption), { color = M.paperInk }))
  end
  table.insert(heading, museum.value(cfg.title, {
    color = M.paperInk,
    fontFamily = cfg.fontFamily or "serif",
    fontSize = cfg.fontSize or 13,
    fontWeight = "bold",
    maxWidth = cfg.titleWidth,
  }))

  local top = { ui.column({ gap = 4, flexGrow = 1, align = "start" }, heading) }
  if cfg.stamp ~= nil then
    table.insert(top, ui.row({
      key = cfg.key and (cfg.key .. "-stamp") or nil,
      border = tone,
      borderWidth = 2,
      radius = 2,
      paddingH = 6,
      paddingV = 3,
      align = "center",
    }, {
      ui.label({
        text = upper(cfg.stamp),
        fontSize = 9,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = tone,
      }),
    }))
  end

  local kids = {
    ui.row({ justify = "space_between", align = "start", gap = 8 }, top),
  }
  if cfg.line ~= nil then
    kids[#kids + 1] = ui.box({ height = 1, fill = M.paper3 })
    kids[#kids + 1] = ui.row({ justify = "space_between", align = "center", gap = 8, paddingV = 6 }, {
      ui.label({
        text = cfg.line,
        fontSize = 11,
        fontFamily = "monospace",
        color = M.paperInk,
        maxLines = cfg.lineLines or 3,
        flexGrow = 1,
      }),
    })
    kids[#kids + 1] = ui.box({ height = 1, fill = M.paper3 })
  end
  if cfg.footerLeft ~= nil or cfg.footerRight ~= nil then
    kids[#kids + 1] = ui.row({ justify = "space_between", align = "center", gap = 8 }, {
      ui.label({
        text = upper(cfg.footerLeft ~= nil and cfg.footerLeft or "—"),
        fontSize = 8.5,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = M.paperDim,
        maxLines = 1,
        flexGrow = 1,
      }),
      ui.label({
        text = upper(cfg.footerRight ~= nil and cfg.footerRight or "—"),
        fontSize = 8.5,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = M.paperDim,
        maxLines = 1,
      }),
    })
  end

  return ui.column({
    key = cfg.key,
    fill = M.paper,
    radius = 2,
    padding = 13,
    gap = 7,
    opacity = cfg.opacity,
    flexGrow = cfg.flexGrow,
    minHeight = cfg.minHeight,
    onClick = cfg.onClick,
  }, kids)
end

-- Readout — a numeral in brass with its unit beside it, a gauge under it, and
-- a secondary line in patina. The instrument-panel cell.
function D.readout(cfg)
  cfg = cfg or {}
  local kids = {
    museum.caption(cfg.label, { fontSize = 8.5 }),
    ui.row({ align = "end", gap = 4 }, {
      museum.value(cfg.value, {
        fontSize = cfg.fontSize or 20,
        fontFamily = "serif",
        fontWeight = "bold",
        color = cfg.color or M.brassLt,
      }),
      ui.label({
        text = cfg.unit ~= nil and tostring(cfg.unit) or "",
        fontSize = 9,
        fontFamily = "monospace",
        color = M.paperDim,
      }),
    }),
  }
  if cfg.meter ~= nil then
    kids[#kids + 1] = museum.gauge({
      value = cfg.meter,
      segments = cfg.segments or 10,
      width = cfg.meterWidth or 84,
      height = 6,
    })
  end
  if cfg.note ~= nil then
    kids[#kids + 1] = ui.label({
      text = tostring(cfg.note),
      fontSize = 10,
      fontFamily = "monospace",
      color = M.patina,
      maxLines = 1,
    })
  end
  return ui.column({ key = cfg.key, gap = 5, flexGrow = cfg.flexGrow }, kids)
end

return D
