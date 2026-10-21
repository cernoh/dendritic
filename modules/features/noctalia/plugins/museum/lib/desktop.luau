--!nonstrict
-- The museum desktop tiles (PLAN.md phase 5), as pure ui.* builders.
--
-- The four `sysmon` cards collapse into one mounted instrument board. Each
-- instrument is a name in small caps, a value in brass, a secondary readout in
-- patina, and a Meter (DESIGN §6.5) — no needle dial, which is Tier B
-- (noctalia's ui.* has no arc or rotation primitive). The clock placard and the
-- month plate restore the drawer's components at desktop scale.
--
-- `lib/museum.luau` is the bar's component library and caps every plate at a
-- bar width; a desktop tile is one fixed surface, so these builders compose the
-- same primitives with the tile's own geometry instead. Nothing here invents a
-- sixth component, and no file carries a museum hex: `museum.t` resolves the
-- palette, including the three role-less materials from `dark.museum`.
--
-- tests/driver-desktop.luau asserts each tree against the stub host.

local museum = require("./museum.luau")

local D = {}

local T = museum.t
D.t = T

local function tr(key)
  return noctalia.tr(key)
end

local function upper(text)
  return string.upper(tostring(text))
end

-- Bytes → GiB, for the VRAM readout. `museum.megabytes` is the bar's MiB
-- formatter; a desktop instrument has room for the guest's own figure.
function D.gib(bytes)
  if bytes == nil or bytes <= 0 then
    return museum.number(nil, "%.1f")
  end
  return string.format("%.1fG", bytes / (1024 * 1024 * 1024))
end

-- Percentage from a used/total pair, with the absent-probe case kept distinct
-- from an idle zero (runtime-api.mdx: absent sensors are nil, not 0).
function D.ratio(used, total)
  if used == nil or total == nil or total <= 0 then
    return nil
  end
  return math.clamp(used / total, 0, 1)
end

-- ── the mounted instrument board ──────────────────────────────────────────

local INSTRUMENT_WIDTH = 231
local INSTRUMENT_HEIGHT = 118

local function instrument(cfg)
  local value = cfg.value or "—"
  local rows = {
    museum.caption(upper(cfg.name), { fontSize = 9, color = T.paperDim }),
    ui.label({
      text = value,
      fontSize = 26,
      fontWeight = "bold",
      color = cfg.valueColor or T.brass,
      fontFamily = "Source Serif 4",
      maxWidth = INSTRUMENT_WIDTH,
      maxLines = 1,
    }),
    museum.caption(cfg.secondary or "—", { fontSize = 10, color = T.patina }),
    museum.gauge({
      value = cfg.ratio or 0,
      segments = 16,
      height = 8,
      width = INSTRUMENT_WIDTH,
      fill = T.brass,
      keyPrefix = (cfg.key or "instrument") .. "-seg-",
    }),
  }
  return ui.column({
    key = cfg.key or ("instrument-" .. cfg.name),
    width = INSTRUMENT_WIDTH,
    height = INSTRUMENT_HEIGHT,
    gap = 2,
    justify = "center",
    align = "start",
  }, rows)
end

-- `stats` is the telemetry service's published snapshot. The field names are
-- the ones the service adds from noctalia.systemStats(); a nil field draws the
-- em dash and a "no probe" note rather than a fabricated zero.
function D.board(cfg)
  local stats = (cfg and cfg.stats) or {}
  local gpu = stats.gpuUsage
  local cpu = stats.cpuUsage
  local ram = stats.ramUsagePercent
  local swap = D.ratio(stats.swapUsedMb, stats.swapTotalMb)
  local vram = D.ratio(stats.vramUsedBytes, stats.vramTotalBytes)

  local vramNote = tr("note.probe")
  if stats.vramTotalBytes ~= nil then
    vramNote = D.gib(stats.vramUsedBytes)
  end

  local ramNote = "—"
  if swap ~= nil then
    ramNote = tr("key.swap") .. " " .. museum.pct(swap * 100)
  end

  local caption = museum.caption(upper(tr("caption.instruments")), {
    fontSize = 9,
    color = T.brass,
  })
  local accession = museum.caption(cfg and cfg.accession or tr("desktop.accession"), {
    fontSize = 8,
    color = T.paperDim,
  })

  return ui.column({
    key = "instrument-board",
    width = 500,
    height = 306,
    paddingH = 14,
    paddingV = 14,
    gap = 10,
    fill = T.walnut2,
    radius = 6,
    border = T.brassDk,
    borderWidth = 1,
    align = "start",
  }, {
    ui.row({
      key = "instrument-caption",
      gap = 8,
      justify = "space_between",
      align = "center",
      width = 472,
    }, { caption, accession }),
    ui.box({ key = "instrument-rule", width = 472, height = 1, fill = T.brassDk .. "/0.6" }),
    ui.column({ key = "instrument-grid", gap = 10, align = "start" }, {
      ui.row({ key = "instrument-row-1", gap = 10, align = "stretch" }, {
        instrument({
          key = "instrument-gpu",
          name = tr("key.gpu") .. " " .. tr("key.load"),
          value = museum.pct(gpu),
          secondary = museum.temp(stats.gpuTempC),
          ratio = gpu ~= nil and math.clamp(gpu / 100, 0, 1) or nil,
        }),
        instrument({
          key = "instrument-vram",
          name = tr("key.vram"),
          value = museum.pct(vram ~= nil and vram * 100 or nil),
          secondary = vramNote,
          ratio = vram,
        }),
      }),
      ui.row({ key = "instrument-row-2", gap = 10, align = "stretch" }, {
        instrument({
          key = "instrument-cpu",
          name = tr("key.cpu") .. " " .. tr("key.load"),
          value = museum.pct(cpu),
          secondary = museum.temp(stats.cpuTempC),
          ratio = cpu ~= nil and math.clamp(cpu / 100, 0, 1) or nil,
        }),
        instrument({
          key = "instrument-ram",
          name = tr("key.ram"),
          value = museum.pct(ram),
          secondary = ramNote,
          ratio = ram ~= nil and math.clamp(ram / 100, 0, 1) or nil,
        }),
      }),
    }),
  })
end

-- ── the clock placard ─────────────────────────────────────────────────────
-- The built-in desktop clock can be brass and serif, but one label cannot show
-- both the time and the date, and it cannot add the level meter. The placard is
-- a plugin tile so the published artifact (§04) stays the acceptance target.
-- The meter is the minute's seconds: one segment per three seconds.

function D.clock(cfg)
  cfg = cfg or {}
  local second = tonumber(cfg.second) or 0
  local filled = math.floor(second / 60 * 20 + 0.5)

  local meter = {}
  for index = 1, 20 do
    table.insert(meter, ui.box({
      key = "clock-seg-" .. index,
      flexGrow = 1,
      height = 8,
      radius = 1,
      fill = index <= filled and T.brass or T.brassDk .. "/0.25",
    }))
  end

  return ui.column({
    key = "clock-placard",
    width = 464,
    height = 96,
    paddingH = 14,
    paddingV = 10,
    gap = 3,
    fill = T.walnut2,
    radius = 6,
    border = T.brassDk,
    borderWidth = 1,
    align = "center",
    justify = "center",
  }, {
    ui.label({
      key = "clock-time",
      text = cfg.time or "—:—",
      fontSize = 34,
      fontWeight = "bold",
      color = T.brassLt,
      fontFamily = "Source Serif 4",
      textAlign = "center",
      maxWidth = 436,
      maxLines = 1,
    }),
    ui.label({
      key = "clock-date",
      text = upper(cfg.date or ""),
      fontSize = 10,
      color = T.paperDim,
      textAlign = "center",
      maxWidth = 436,
      maxLines = 1,
    }),
    ui.row({ key = "clock-meter", gap = 2, align = "center", width = 260, flexGrow = 1 }, meter),
  })
end

-- ── the month plate ───────────────────────────────────────────────────────
-- Same component as the drawer's VIII (panel.luau), at the desktop's 620×420.
-- Monday-first, whole weeks, today embossed in brass, and the wall text pinned
-- to the bottom of the plate.

function D.monthCells(offset)
  local now = os.date("*t")
  local first = os.time({ year = now.year, month = now.month + offset, day = 1, hour = 12 })
  local firstDate = os.date("*t", first)
  local year, month = firstDate.year, firstDate.month
  local length = tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0, hour = 12 })))
  local previousLength = tonumber(os.date("%d", os.time({ year = year, month = month, day = 0, hour = 12 })))
  local startColumn = ((firstDate.wday - 2) % 7) + 1

  local weeks = {}
  local week = {}
  for index = 1, startColumn - 1 do
    week[#week + 1] = {
      day = previousLength - (startColumn - 1 - index),
      inMonth = false,
      key = "lead-" .. tostring(index),
    }
  end
  for day = 1, length do
    week[#week + 1] = {
      day = day,
      inMonth = true,
      key = string.format("%04d-%02d-%02d", year, month, day),
    }
    if #week == 7 then
      weeks[#weeks + 1] = week
      week = {}
    end
  end
  if #week > 0 then
    local fill = 1
    while #week < 7 do
      week[#week + 1] = { day = fill, inMonth = false, key = "trail-" .. tostring(fill) }
      fill = fill + 1
    end
    weeks[#weeks + 1] = week
  end

  return {
    label = os.date("%B %Y", first),
    weeks = weeks,
    isCurrentMonth = year == now.year and month == now.month,
    today = now,
  }
end

local WEEKDAYS = {
  "weekday.mon",
  "weekday.tue",
  "weekday.wed",
  "weekday.thu",
  "weekday.fri",
  "weekday.sat",
  "weekday.sun",
}

function D.month(cfg)
  cfg = cfg or {}
  local cells = D.monthCells(cfg.offset or 0)
  local today = cells.today

  local weekdayRow = {}
  for _, key in ipairs(WEEKDAYS) do
    table.insert(weekdayRow, ui.column({ flexGrow = 1, align = "center" }, {
      museum.caption(upper(tr(key)), { fontSize = 9, color = T.paperDim }),
    }))
  end

  local weekRows = {}
  for _, week in ipairs(cells.weeks) do
    local row = {}
    for column, day in ipairs(week) do
      local isToday = cells.isCurrentMonth and day.inMonth and day.day == today.day
      local color = T.bone
      if not day.inMonth then
        color = T.paperDim .. "/0.4"
      elseif column >= 6 then
        color = T.paperDim
      end
      if isToday then
        color = T.brassInk
      end
      table.insert(row, ui.column({
        key = "month-day-" .. day.key,
        flexGrow = 1,
        align = "center",
        paddingV = 5,
        radius = 3,
        fill = isToday and T.brass or nil,
      }, {
        ui.label({
          text = tostring(day.day),
          fontSize = 13,
          fontFamily = "Source Serif 4",
          color = color,
          fontWeight = isToday and "bold" or nil,
        }),
      }))
    end
    table.insert(weekRows, ui.row({ key = "month-week-" .. #weekRows, gap = 1, align = "stretch" }, row))
  end

  local eventLine = os.date("%A ", os.time(today)) .. tostring(today.day) .. os.date(" %B", os.time(today))
    .. " " .. tr("desktop.month.noevents")

  return ui.column({
    key = "month-plate",
    width = 620,
    height = 420,
    paddingH = 14,
    paddingV = 14,
    gap = 8,
    fill = T.walnut2,
    radius = 6,
    border = T.brassDk,
    borderWidth = 1,
    align = "stretch",
  }, {
    ui.row({ key = "month-caption", gap = 8, justify = "space_between", align = "center" }, {
      museum.caption(upper(tr("caption.monthplate")), { fontSize = 9, color = T.brass }),
      museum.caption(upper(cells.label), { fontSize = 8, color = T.paperDim }),
    }),
    ui.box({ key = "month-rule", height = 1, fill = T.brassDk .. "/0.6" }),
    ui.row({ key = "month-header", gap = 6, align = "center", justify = "space_between" }, {
      ui.button({
        key = "month-prev",
        glyph = "chevron-left",
        glyphSize = 15,
        variant = "ghost",
        controlSize = "sm",
        tooltip = tr("action.previous"),
        onClick = cfg.onPrev,
      }),
      ui.label({
        key = "month-title",
        text = cells.label,
        fontSize = 18,
        fontWeight = "bold",
        fontFamily = "Source Serif 4",
        color = T.bone,
        flexGrow = 1,
        textAlign = "center",
        maxLines = 1,
      }),
      ui.button({
        key = "month-next",
        glyph = "chevron-right",
        glyphSize = 15,
        variant = "ghost",
        controlSize = "sm",
        tooltip = tr("action.next"),
        onClick = cfg.onNext,
      }),
    }),
    ui.row({ key = "month-weekdays", gap = 1, align = "stretch" }, weekdayRow),
    ui.column({ key = "month-weeks", gap = 2 }, weekRows),
    ui.spacer({ key = "month-spacer", flexGrow = 1 }),
    ui.box({ key = "month-wall-rule", height = 1, fill = T.brassDk .. "/0.5" }),
    museum.caption(upper(tr("caption.walltext")), { fontSize = 8, color = T.brass }),
    ui.label({
      key = "month-wall-text",
      text = eventLine,
      fontSize = 14,
      fontFamily = "Source Serif 4",
      color = T.paperDim,
      maxLines = 2,
    }),
  })
end

return D
