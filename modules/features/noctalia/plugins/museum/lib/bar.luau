--!nonstrict
-- The six museum bar families, as pure ui.* builders.
--
-- Each function returns one `ui.row` (the bar is horizontal; the entries branch
-- on barWidget.isVertical and fall back to nothing when it is vertical) and
-- reads its width cap from museum.width — no instance passes a width.
--
-- The artifact is museum-reskin-before-after.html §01: halls · wall label ·
-- MACHINE · clock · THERMAL + fuel gauge · exhibit · tray plate · wax seal ·
-- audio plate · brass power.

local museum = require("./museum.luau")
local mango = require("./mango.luau")

local M = {}
local W = museum.width

local function tr(key)
  return noctalia.tr(key)
end

-- ── halls ──────────────────────────────────────────────────────────────────

function M.halls(cfg)
  local plates = {}
  for _, tag in ipairs(cfg.tags or {}) do
    local active = tag.is_active == true
    table.insert(plates, ui.button({
      key = "hall-" .. tostring(tag.index),
      text = museum.roman(tag.index),
      variant = active and "primary" or "ghost",
      selected = active,
      fontSize = 12,
      fontWeight = "bold",
      width = W.hallPlate,
      tooltip = string.format("Hall %s", museum.roman(tag.index)),
      onClick = function()
        cfg.onSelect(tag.index)
      end,
    }))
  end
  if #plates == 0 then
    return nil
  end

  local width = math.min(W.halls, #plates * W.hallPlate + (#plates - 1) * 2 + 16)
  return ui.row({
    key = "halls",
    width = width,
    gap = 2,
    paddingH = 5,
    paddingV = 3,
    align = "center",
    fill = museum.t.walnut2,
    radius = 4,
    border = museum.t.brassDk,
    borderWidth = 1,
  }, plates)
end

-- ── wall label (NOW VIEWING) ───────────────────────────────────────────────

function M.label(cfg)
  local title = museum.truncate(cfg.title or "", cfg.maxLength or 260)
  if title == "" then
    title = tr("bar.no_window")
  end
  return museum.slip({
    key = "now-viewing",
    width = W.label,
    caption = cfg.caption or tr("bar.now_viewing"),
    title = title,
    fontFamily = "DejaVu Serif",
  })
end

-- ── MACHINE plaque ────────────────────────────────────────────────────────

function M.machine(cfg)
  local stats = cfg.stats or {}
  local cells = {
    { key = tr("key.ram"), value = museum.megabytes(stats.ramUsedMb) },
    { key = tr("key.cpu"), value = museum.pct(stats.cpuUsage) },
  }
  if cfg.showGpu ~= false then
    table.insert(cells, { key = tr("key.gpu"), value = museum.pct(stats.gpuUsage) })
  end
  return museum.plate({
    id = "machine",
    caption = tr("bar.machine"),
    body = museum.ledger({
      orientation = "row",
      gap = 7,
      valueSize = 12,
      cells = cells,
    }),
  })
end

-- ── clock placard ─────────────────────────────────────────────────────────

function M.clock(cfg)
  return ui.column({
    key = "clock",
    width = W.clock,
    gap = 0,
    align = "center",
  }, {
    ui.label({
      text = cfg.time or "",
      fontSize = 17,
      fontWeight = "bold",
      color = museum.t.brass,
      fontFamily = "DejaVu Serif",
      maxWidth = W.clock,
      maxLines = 1,
    }),
    ui.label({
      text = cfg.date or "",
      fontSize = 10,
      color = museum.t.paperDim,
      fontFamily = "DejaVu Serif",
      maxWidth = W.clock,
      maxLines = 1,
    }),
  })
end

-- ── THERMAL plaque + drive fuel gauge ─────────────────────────────────────

function M.thermal(cfg)
  local stats = cfg.stats or {}
  local drives = cfg.drives or {}
  local plate = museum.plate({
    id = "thermal",
    caption = tr("bar.thermal"),
    body = museum.ledger({
      orientation = "row",
      gap = 7,
      valueSize = 12,
      cells = {
        { key = tr("key.cpu"), value = museum.temp(stats.cpuTempC) },
        { key = tr("key.drv"), value = museum.temp(drives.tempC) },
      },
    }),
  })
  if cfg.showGauge == false then
    return plate
  end

  local degraded = drives.degradedPct or 0
  local gauge = ui.row({
    key = "drive-gauge",
    width = W.gauge,
    gap = 4,
    align = "center",
  }, {
    ui.glyph({ name = "server", size = 14, color = museum.t.paperDim }),
    museum.gauge({
      value = degraded / 100,
      width = W.gauge - 56,
      segments = 10,
      height = 8,
    }),
    museum.value(museum.pct(drives.degradedPct), {
      fontSize = 11,
      color = museum.t.patina,
      maxWidth = 30,
    }),
  })
  return ui.row({ key = "thermal-entry", gap = 6, align = "center" }, { plate, gauge })
end

-- ── tray: exhibit · tray plate · wax seal · audio plate · power ───────────

local TRAY_TABS = {
  { glyph = "notification", tab = "notifications", label = "bar.notifications" },
  { glyph = "clipboard", tab = "clipboard", label = "bar.clipboard" },
  { glyph = "wifi", tab = "network", label = "bar.network" },
  { glyph = "bluetooth", tab = "bluetooth", label = "bar.bluetooth" },
}

local function openTab(tab)
  return function()
    mango.msg("panel-toggle", "control-center", tab)
  end
end

local function glyphButton(item, size)
  return ui.button({
    key = "tray-" .. item.tab,
    glyph = item.glyph,
    glyphSize = 14,
    variant = "ghost",
    width = size or 20,
    tooltip = tr(item.label),
    onClick = openTab(item.tab),
  })
end

function M.tray(cfg)
  local media = cfg.media
  local playing = media ~= nil and media.status == "Playing"
  local title = media ~= nil and media.title or ""
  if title == "" then
    title = tr("bar.no_exhibit")
  end

  local exhibit = ui.row({
    key = "exhibit",
    width = W.exhibit,
    gap = 5,
    paddingH = 6,
    paddingV = 3,
    align = "center",
    fill = museum.t.walnut2,
    radius = 4,
    border = museum.t.brassDk,
    borderWidth = 1,
    tooltip = tr("bar.media"),
    onClick = openTab("media"),
  }, {
    ui.glyph({
      name = playing and "player-pause" or "music",
      size = 14,
      color = playing and museum.t.brass or museum.t.paperDim,
    }),
    museum.value(museum.truncate(title, 22), {
      fontSize = 12,
      color = museum.t.paperDim,
      maxWidth = W.exhibit - 30,
    }),
  })

  local trayGlyphs = {}
  for _, item in ipairs(TRAY_TABS) do
    table.insert(trayGlyphs, glyphButton(item))
  end
  local trayPlate = ui.row({
    key = "tray-plate",
    width = W.tray,
    gap = 2,
    paddingH = 4,
    paddingV = 3,
    align = "center",
    fill = museum.t.walnut2,
    radius = 4,
    border = museum.t.brassDk,
    borderWidth = 1,
  }, trayGlyphs)

  local parts = { exhibit, trayPlate }

  local unread = cfg.unread or 0
  if cfg.showUnread ~= false and unread > 0 then
    table.insert(parts, ui.column({
      key = "wax-seal",
      width = 20,
      height = 20,
      align = "center",
      justify = "center",
      fill = museum.t.inkRed,
      radius = 10,
      tooltip = tr("bar.notifications"),
      onClick = openTab("notifications"),
    }, {
      ui.label({
        text = tostring(unread),
        fontSize = 10,
        fontWeight = "bold",
        color = museum.t.paper,
        maxLines = 1,
      }),
    }))
  end

  if cfg.showAudio ~= false then
    local audio = cfg.audio or {}
    table.insert(parts, museum.plate({
      id = "audio",
      caption = tr("bar.audio"),
      body = ui.row({ gap = 7, align = "center" }, {
        museum.keyValue(tr("key.vol"), museum.pct(audio.volume), { valueSize = 12 }),
        museum.keyValue(tr("key.bri"), museum.pct(audio.brightness), { valueSize = 12 }),
      }),
      key = "audio-plate",
    }))
  end

  table.insert(parts, ui.button({
    key = "power",
    glyph = "power",
    glyphSize = 16,
    variant = "primary",
    width = W.power,
    height = 28,
    tooltip = tr("bar.session"),
    onClick = function()
      mango.msg("panel-toggle", "session")
    end,
  }))

  return ui.row({ key = "tray", gap = 6, align = "center" }, parts)
end

-- ── entry helper ──────────────────────────────────────────────────────────

-- Every museum widget is horizontal. On a vertical bar the entries hide
-- instead of rendering a broken one-control-tall column.
function M.horizontal()
  if barWidget.isVertical() then
    return false
  end
  return true
end

return M
