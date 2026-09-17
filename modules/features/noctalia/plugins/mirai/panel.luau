--!nonstrict
-- Renders the Mirai panel: the daemon, the sink controls, and the displays
-- found for casting.
--
-- The layout copies the Bluetooth tab of the control center, translated into
-- the plugin UI vocabulary:
--   * a status card with one row per control (the tab's adapter card),
--   * one card per group of rows, each headed by a bold title row
--     (`makeCardHeaderRow`),
--   * one row per display or link, shaped like `BluetoothDeviceRow`: a kind
--     glyph, the name (bold while active), metric pills, then the actions.
-- Card fill, radius, and padding follow `applySectionCardStyle`, at the card
-- opacity `panelCardOpacityForTransparencyMode` gives for `soft`.
--
-- This script reads state and posts work. It never runs a command: the service
-- owns the CLI.

local CARD_FILL = "surface_variant/0.92"
local CARD_RADIUS = 12
local ROW_FILL = "surface"
local ROW_RADIUS = 6
local SECTION_HEIGHT = 32
local ROW_HEIGHT = 28

local MODES = { "window", "fullscreen" }

local open = false
local snapshot = noctalia.state.get("snapshot")
local busy = noctalia.state.get("busy") or ""
local message = noctalia.state.get("message") or ""
local needsRoot = noctalia.state.get("needs_root") == true

local function tr(key, subst)
  return noctalia.tr(key, subst)
end

-- Post work to the service. The revision counter makes two identical requests
-- in a row both run, which a bare value comparison would swallow.
local function request(kind, payload)
  noctalia.state.set("request", { kind = kind, payload = payload })
  noctalia.state.set("request_rev", (tonumber(noctalia.state.get("request_rev")) or 0) + 1)
end

local function isBusy()
  return busy ~= nil and busy ~= ""
end

local function isInstalled()
  return snapshot ~= nil and snapshot.installed == true
end

local function isRunning()
  return snapshot ~= nil and snapshot.running == true
end

local function sinkState()
  if snapshot ~= nil and snapshot.sink ~= nil then
    return snapshot.sink
  end
  return {}
end

local function sourceState()
  if snapshot ~= nil and snapshot.source ~= nil then
    return snapshot.source
  end
  return {}
end

local function statusText()
  if snapshot == nil then
    return tr("status.waiting"), "on_surface_variant"
  end
  if not isInstalled() then
    return tr("status.absent"), "on_surface_variant"
  end
  if not isRunning() then
    return tr("status.stopped"), "on_surface_variant"
  end
  if snapshot.mode == "sink" then
    return tr("status.receiving"), "primary"
  end
  if snapshot.mode == "source" then
    return tr("status.casting"), "primary"
  end
  return tr("status.idle"), "primary"
end

local function displayOptions()
  local options = { tr("display.portal") }
  for _, display in ipairs((snapshot ~= nil and snapshot.displays) or {}) do
    table.insert(options, tostring(display.name))
  end
  return options
end

local function displayIndex()
  local current = sourceState().display
  if current == nil or current == "" or current == "default" then
    return 0
  end
  local options = displayOptions()
  for index, name in ipairs(options) do
    if name == current then
      return index - 1
    end
  end
  return 0
end

local function modeIndex()
  local current = sinkState().mode
  for index, name in ipairs(MODES) do
    if name == current then
      return index - 1
    end
  end
  return 0
end

local function protocolGlyph(protocol)
  if protocol == "mice" then
    return "cast"
  end
  if protocol == "p2p" then
    return "device-mobile"
  end
  return "link"
end

local function card(children)
  return ui.column({
    fill = CARD_FILL,
    radius = CARD_RADIUS,
    border = "outline",
    borderWidth = 1,
    padding = 12,
    gap = 8,
    align = "stretch",
  }, children)
end

local function controlRow(children)
  return ui.row({ align = "center", gap = 8, minHeight = SECTION_HEIGHT }, children)
end

local function sectionHeader(title, trailing)
  local children = {
    ui.label({ text = title, fontSize = 14, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
  }
  for _, control in ipairs(trailing or {}) do
    table.insert(children, control)
  end
  return ui.row({ align = "center", gap = 8, minHeight = SECTION_HEIGHT }, children)
end

local function metricPill(glyph, text)
  return ui.row({ align = "center", gap = 2 }, {
    ui.glyph({ name = glyph, size = 13, color = "on_surface_variant" }),
    ui.label({ text = text, fontSize = 13, color = "on_surface_variant" }),
  })
end

local function busyLabel()
  if not isBusy() then
    return nil
  end
  return ui.label({ text = tr("busy." .. tostring(busy)), fontSize = 13, color = "primary" })
end

local function scanButton()
  return ui.button({
    glyph = "refresh",
    variant = "ghost",
    controlSize = "sm",
    tooltip = tr("tooltip.scan"),
    enabled = isRunning() and not isBusy(),
    onClick = "onScan",
  })
end

-- One device row: the surface row of `BluetoothDeviceRow`.
local function deviceRow(options)
  local children = {
    ui.glyph({ name = options.glyph, size = 16, color = options.active and "primary" or "on_surface" }),
    ui.label({
      text = options.title,
      fontSize = 14,
      fontWeight = options.active and "bold" or "normal",
      color = "on_surface",
      flexGrow = 1,
      maxLines = 1,
    }),
  }
  for _, pill in ipairs(options.metrics or {}) do
    table.insert(children, pill)
  end
  if options.status ~= nil then
    table.insert(children, ui.label({ text = options.status, fontSize = 13, color = "on_surface_variant" }))
  end
  for _, action in ipairs(options.actions or {}) do
    table.insert(children, action)
  end

  return ui.column({
    key = options.key,
    fill = ROW_FILL,
    radius = ROW_RADIUS,
    paddingH = 12,
    paddingV = 8,
  }, {
    ui.row({ align = "center", gap = 8, minHeight = ROW_HEIGHT }, children),
  })
end

local function headerRow()
  local status, color = statusText()
  return ui.row({ align = "center", gap = 8, height = 28 }, {
    ui.glyph({ name = "cast", size = 18, color = "primary" }),
    ui.label({ text = tr("title"), fontWeight = "bold", flexGrow = 1 }),
    ui.label({ text = status, color = color }),
    ui.button({
      glyph = "refresh",
      variant = "ghost",
      tooltip = tr("tooltip.refresh"),
      enabled = isInstalled() and not isBusy(),
      onClick = "onRefresh",
    }),
    ui.button({ glyph = "x", variant = "ghost", tooltip = tr("tooltip.close"), onClick = "onCloseClicked" }),
  })
end

local function daemonCard()
  local running = isRunning()
  local sink = sinkState()

  local daemonRow = {
    ui.label({ text = tr("label.daemon"), fontSize = 14, color = "on_surface", flexGrow = 1 }),
  }
  local label = busyLabel()
  if label ~= nil then
    table.insert(daemonRow, label)
  end
  table.insert(daemonRow, ui.button({
    glyph = "refresh",
    variant = "ghost",
    controlSize = "sm",
    tooltip = tr("tooltip.refresh"),
    enabled = not isBusy(),
    onClick = "onRefresh",
  }))
  table.insert(daemonRow, ui.toggle({ checked = running, enabled = not isBusy(), onChange = "onDaemonToggle" }))

  local sinkRow = {
    ui.glyph({ name = "device-tv", size = 16, color = "on_surface" }),
    ui.label({ text = tr("label.receive"), fontSize = 14, color = "on_surface", flexGrow = 1 }),
  }
  if sink.running == true then
    table.insert(sinkRow, ui.label({
      text = noctalia.trp("label.links", #(sink.links or {})),
      fontSize = 13,
      color = "on_surface_variant",
    }))
  end
  table.insert(sinkRow, ui.toggle({
    checked = sink.running == true,
    enabled = running and not isBusy(),
    onChange = "onSinkToggle",
  }))

  local rows = {
    controlRow(daemonRow),
    controlRow(sinkRow),
    controlRow({
      ui.glyph({ name = "device-tv", size = 16, color = "on_surface" }),
      ui.label({ text = tr("label.sink_mode"), fontSize = 14, color = "on_surface", flexGrow = 1 }),
      ui.select({
        options = { tr("mode.window"), tr("mode.fullscreen") },
        selectedIndex = modeIndex(),
        controlSize = "sm",
        width = 150,
        enabled = running,
        onChange = "onSinkMode",
      }),
    }),
    controlRow({
      ui.glyph({ name = "device-desktop", size = 16, color = "on_surface" }),
      ui.label({ text = tr("label.share_display"), fontSize = 14, color = "on_surface", flexGrow = 1 }),
      ui.select({
        options = displayOptions(),
        selectedIndex = displayIndex(),
        controlSize = "sm",
        width = 150,
        enabled = running,
        onChange = "onShareDisplay",
      }),
    }),
    controlRow({
      ui.label({ text = tr("label.sessions"), fontSize = 14, color = "on_surface", flexGrow = 1 }),
      ui.button({
        text = tr("button.stop_all"),
        variant = "ghost",
        controlSize = "sm",
        enabled = snapshot.mode ~= nil and not isBusy(),
        onClick = "onStopAll",
      }),
    }),
  }

  if needsRoot then
    table.insert(rows, controlRow({
      ui.glyph({ name = "alert-triangle", size = 16, color = "error" }),
      ui.label({
        text = tr("hint.needs_root"),
        fontSize = 13,
        color = "on_surface_variant",
        flexGrow = 1,
        maxLines = 3,
      }),
      ui.button({
        text = tr("button.start_root"),
        variant = "primary",
        controlSize = "sm",
        onClick = "onStartRoot",
      }),
    }))
  end

  return card(rows)
end

local function noticeCard(text)
  return card({
    ui.label({ text = text, fontSize = 13, color = "error", maxLines = 4 }),
  })
end

local function missingCard()
  return card({
    ui.label({ text = tr("hint.missing_title"), fontSize = 14, fontWeight = "bold", color = "on_surface" }),
    ui.label({ text = tr("hint.missing_body"), fontSize = 13, color = "on_surface_variant", maxLines = 4 }),
  })
end

local function stoppedCard()
  local buttons = {
    ui.button({
      text = tr("button.start_daemon"),
      variant = "primary",
      controlSize = "sm",
      enabled = not isBusy(),
      onClick = "onStartDaemon",
    }),
    ui.button({
      text = tr("button.start_root"),
      variant = "ghost",
      controlSize = "sm",
      onClick = "onStartRoot",
    }),
  }
  return card({
    ui.label({ text = tr("hint.daemon_stopped"), fontSize = 14, fontWeight = "bold", color = "on_surface" }),
    ui.label({ text = tr("hint.daemon_stopped_body"), fontSize = 13, color = "on_surface_variant", maxLines = 3 }),
    ui.row({ align = "center", gap = 8 }, buttons),
  })
end

local function sinkRowFor(sink, active, current)
  local actions = {}
  if current then
    table.insert(actions, ui.button({
      glyph = "cast-off",
      variant = "destructive",
      controlSize = "sm",
      tooltip = tr("tooltip.disconnect"),
      enabled = not isBusy(),
      onClick = "onDisconnect",
    }))
  else
    table.insert(actions, ui.button({
      glyph = "cast",
      variant = "default",
      controlSize = "sm",
      tooltip = tr("tooltip.connect"),
      enabled = not isBusy(),
      onClick = function()
        request("connect", tostring(sink.id))
      end,
    }))
  end

  local metrics = {
    metricPill(protocolGlyph(sink.protocol), tostring(sink.protocol or "unknown")),
  }
  if sink.ip ~= nil then
    table.insert(metrics, metricPill("network", tostring(sink.ip)))
  end

  return deviceRow({
    key = "sink-" .. tostring(sink.id),
    glyph = protocolGlyph(sink.protocol),
    title = tostring(sink.name or sink.id),
    active = active,
    metrics = metrics,
    actions = actions,
  })
end

local function connectedCard()
  local source = sourceState()
  local current = source.current
  if current == nil or snapshot.mode ~= "source" then
    return nil
  end

  local children = { sectionHeader(tr("section.connected")) }
  table.insert(children, sinkRowFor(current, true, true))
  return card(children)
end

local function nearbyCard()
  local source = sourceState()
  local current = source.current
  local children = { sectionHeader(tr("section.nearby"), { scanButton() }) }

  local others = {}
  for _, sink in ipairs(source.sinks or {}) do
    if current == nil or tostring(sink.id) ~= tostring(current.id) then
      table.insert(others, sink)
    end
  end

  if source.scanning == true then
    table.insert(children, ui.label({ text = tr("hint.scanning"), fontSize = 13, color = "primary" }))
  elseif #others == 0 then
    table.insert(children, ui.label({
      text = tr("hint.no_sinks"),
      fontSize = 13,
      color = "on_surface_variant",
      maxLines = 3,
    }))
  else
    for _, sink in ipairs(others) do
      table.insert(children, sinkRowFor(sink, false, false))
    end
  end

  return card(children)
end

local function receivingCard()
  local sink = sinkState()
  local links = sink.links or {}
  local children = { sectionHeader(tr("section.receiving")) }

  if #links == 0 then
    table.insert(children, ui.label({
      text = tr("hint.waiting_link"),
      fontSize = 13,
      color = "on_surface_variant",
      maxLines = 3,
    }))
  else
    for _, link in ipairs(links) do
      local peers = 0
      for _, peer in ipairs(sink.peers or {}) do
        if tonumber(peer.link) == tonumber(link.id) then
          peers = peers + 1
        end
      end
      table.insert(children, deviceRow({
        key = "link-" .. tostring(link.id),
        glyph = "device-tv",
        title = tostring(sink.friendly_name or tr("title")),
        active = sink.player_running == true and tonumber(sink.current_link) == tonumber(link.id),
        metrics = {
          metricPill("link", tr("label.link", { id = tostring(link.id) })),
          metricPill("device-mobile", noctalia.trp("label.peers", peers)),
        },
        status = tostring(link.state or ""),
      }))
    end
  end

  return card(children)
end

local function render()
  if not open then
    return
  end

  local sections = {}

  if snapshot == nil then
    table.insert(sections, card({
      ui.label({ text = tr("hint.loading"), fontSize = 13, color = "on_surface_variant" }),
    }))
  elseif not isInstalled() then
    table.insert(sections, missingCard())
  else
    table.insert(sections, daemonCard())
    if message ~= "" then
      table.insert(sections, noticeCard(message))
    end
    if not isRunning() then
      table.insert(sections, stoppedCard())
    else
      if sinkState().running == true then
        table.insert(sections, receivingCard())
      end
      local connected = connectedCard()
      if connected ~= nil then
        table.insert(sections, connected)
      end
      table.insert(sections, nearbyCard())
    end
  end

  panel.render(ui.column({
    flexGrow = 1,
    gap = 10,
    padding = 14,
    fill = "surface",
    radius = 10,
    border = "outline",
    borderWidth = 1,
  }, {
    headerRow(),
    ui.separator({ thickness = 1, color = "outline/0.55" }),
    ui.scroll({ flexGrow = 1, gap = 12, padding = 2 }, sections),
  }))
end

local function readState()
  snapshot = noctalia.state.get("snapshot")
  busy = noctalia.state.get("busy") or ""
  message = noctalia.state.get("message") or ""
  needsRoot = noctalia.state.get("needs_root") == true
end

noctalia.state.watch("snapshot", function(value)
  snapshot = value
  render()
end)

noctalia.state.watch("busy", function(value)
  busy = value or ""
  render()
end)

noctalia.state.watch("message", function(value)
  message = value or ""
  render()
end)

noctalia.state.watch("needs_root", function(value)
  needsRoot = value == true
  render()
end)

function onOpen()
  open = true
  readState()
  request("refresh")
  render()
end

function onClose()
  open = false
end

function onRefresh()
  request("refresh")
end

function onDaemonToggle(value)
  if value == "true" then
    request("daemon_start")
  else
    request("daemon_stop")
  end
end

function onSinkToggle(value)
  if value == "true" then
    request("sink_start")
  else
    request("sink_stop")
  end
end

function onSinkMode(value)
  local index = (tonumber(value) or 0) + 1
  request("sink_mode", MODES[index] or "window")
end

function onShareDisplay(value)
  local index = tonumber(value) or 0
  if index == 0 then
    request("display", "")
    return
  end
  request("display", displayOptions()[index + 1] or "")
end

function onDisconnect()
  request("disconnect")
end

function onStopAll()
  request("stop_all")
end

function onScan()
  request("scan")
end

function onStartDaemon()
  request("daemon_start")
end

function onStartRoot()
  request("daemon_root")
end

function onCloseClicked()
  panel.close()
end
