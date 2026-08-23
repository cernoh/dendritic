--!nonstrict
-- The panel is a thin client of the persistent shell service. Its outline marks
-- the panel boundary against the bar and keeps the terminal visually embedded.

local open = false
local output = noctalia.state.get("output") or "Starting persistent shell…\n"
local status = noctalia.state.get("status") or "starting"
local inputKey = 0
local scrollRevision = 0

local function statusLabel()
  if status == "ready" then
    return "Shell running"
  elseif status == "unavailable" then
    return "Shell unavailable"
  end
  return "Starting shell…"
end

local function render()
  if not open then
    return
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
    ui.row({ align = "center", gap = 8, height = 28 }, {
      ui.glyph({ name = "terminal-2", size = 18, color = "primary" }),
      ui.label({ text = "Terminal", fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = statusLabel(), color = status == "ready" and "primary" or "on_surface_variant" }),
      ui.button({ text = "Open terminal", glyph = "external-link", variant = "ghost", tooltip = "Open the configured terminal emulator", onClick = "onOpenExternal" }),
      ui.button({ glyph = "trash", variant = "ghost", tooltip = "Clear terminal output", onClick = "onClear" }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = "Close terminal", onClick = "onCloseClicked" }),
    }),
    ui.separator({ thickness = 1, color = "outline/0.55" }),
    ui.scroll({
      flexGrow = 1,
      gap = 8,
      padding = 12,
      fill = "surface_variant/0.55",
      radius = 8,
      border = "outline/0.7",
      borderWidth = 1,
      stickToBottom = true,
      scrollToBottomRev = scrollRevision,
    }, {
      ui.label({
        text = output,
        fontFamily = "monospace",
        color = "on_surface",
        maxLines = 2000,
      }),
    }),
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = ">", color = "primary", fontFamily = "monospace" }),
      ui.input({
        key = "command-" .. tostring(inputKey),
        placeholder = "Type a command and press Enter",
        submitOnEnter = true,
        focus = true,
        flexGrow = 1,
        onSubmit = "onSubmit",
      }),
    }),
  }))
end

noctalia.state.watch("output", function(value)
  output = value or ""
  scrollRevision += 1
  render()
end)

noctalia.state.watch("status", function(value)
  status = value or "starting"
  render()
end)

function onOpen(_context)
  open = true
  output = noctalia.state.get("output") or output
  status = noctalia.state.get("status") or status
  render()
end

function onClose()
  open = false
end

function onSubmit(command)
  command = tostring(command or "")
  if command:gsub("%s+", "") == "" then
    return
  end

  local revision = (tonumber(noctalia.state.get("input_revision")) or 0) + 1
  noctalia.state.set("input", command)
  noctalia.state.set("input_revision", revision)
  inputKey += 1
  render()
end

function onOpenExternal()
  noctalia.runInTerminal("exec \"${SHELL:-sh}\"")
end

function onClear()
  noctalia.state.set("output", "")
end

function onCloseClicked()
  panel.close()
end
