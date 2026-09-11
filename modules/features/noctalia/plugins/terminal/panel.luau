--!nonstrict
-- Renders the screen published by the service.
--
-- The panel API has no canvas and no per-cell background, so a frame is drawn
-- the only faithful way it allows: one row per terminal line, and one text run
-- per colour change in that row. Runs sit in a gap-free row, so a monospace
-- font keeps the shell columns aligned. Each run carries its own colour and
-- bold flag, which is exactly what the old regular-expression version deleted.

local FONT_SIZE = 13
local MAX_ROWS = 40
local MAX_RUNS = 64

local open = false
local frame = noctalia.state.get("frame")
local status = noctalia.state.get("status") or "starting"
local statusMessage = noctalia.state.get("status_message") or ""
local inputKey = 0

local function statusLabel()
  if status == "ready" then
    return "Running"
  elseif status == "exited" then
    return "Shell exited"
  elseif status == "unavailable" then
    return statusMessage ~= "" and statusMessage or "Backend unavailable"
  end
  return "Starting"
end

local function defaultForeground()
  if frame ~= nil and frame.dfg ~= nil then
    return frame.dfg
  end
  return "on_surface"
end

local function renderRun(run, index)
  local label = {
    key = "run-" .. tostring(index),
    text = tostring(run.t or ""),
    fontFamily = "monospace",
    fontSize = FONT_SIZE,
    color = run.f or defaultForeground(),
  }
  if run.b then
    label.fontWeight = "bold"
  end
  return ui.label(label)
end

local function renderRow(row, index)
  if row == nil or #row == 0 then
    -- A blank terminal line still occupies a line, so give it one.
    return ui.row({ key = "row-" .. tostring(index), gap = 0 }, {
      ui.label({ text = " ", fontFamily = "monospace", fontSize = FONT_SIZE }),
    })
  end

  local children = {}
  for runIndex = 1, math.min(#row, MAX_RUNS) do
    table.insert(children, renderRun(row[runIndex], runIndex))
  end
  return ui.row({ key = "row-" .. tostring(index), gap = 0 }, children)
end

local function renderScreen()
  local rows = {}
  if frame ~= nil and frame.L ~= nil then
    for index = 1, math.min(#frame.L, MAX_ROWS) do
      table.insert(rows, renderRow(frame.L[index], index))
    end
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "Waiting for the terminal…", color = "on_surface_variant" }))
  end
  return rows
end

local function render()
  if not open then
    return
  end

  local background = frame ~= nil and frame.dbg or "surface_variant"
  local isReady = status == "ready"

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
      ui.label({
        text = statusLabel(),
        color = isReady and "primary" or "on_surface_variant",
      }),
      ui.button({
        glyph = "chevron-up",
        variant = "ghost",
        tooltip = "Scroll back one page",
        enabled = isReady,
        onClick = "onScrollUp",
      }),
      ui.button({
        glyph = "chevron-down",
        variant = "ghost",
        tooltip = "Scroll forward one page",
        enabled = isReady,
        onClick = "onScrollDown",
      }),
      ui.button({
        glyph = "refresh",
        variant = "ghost",
        tooltip = "Restart the shell",
        onClick = "onRestart",
      }),
      ui.button({
        text = "New window",
        glyph = "external-link",
        variant = "ghost",
        tooltip = "Open the configured terminal emulator",
        onClick = "onOpenExternal",
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = "Close", onClick = "onCloseClicked" }),
    }),
    ui.separator({ thickness = 1, color = "outline/0.55" }),
    ui.scroll({
      flexGrow = 1,
      gap = 0,
      padding = 10,
      fill = background,
      radius = 8,
      border = "outline/0.7",
      borderWidth = 1,
      -- Follow new output, but release the pin when the user scrolls away.
      -- Forcing the bottom on every frame would make history unreadable while
      -- a command is still writing.
      stickToBottom = true,
    }, renderScreen()),
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = ">", color = "primary", fontFamily = "monospace" }),
      ui.input({
        key = "command-" .. tostring(inputKey),
        placeholder = isReady and "Type a command and press Enter" or "The terminal is not ready",
        submitOnEnter = true,
        focus = true,
        enabled = isReady,
        flexGrow = 1,
        onSubmit = "onSubmit",
      }),
    }),
  }))
end

-- Post work to the service. The revision counter makes two identical requests
-- in a row both run, which a bare value comparison would swallow.
local function request(kind, payload)
  noctalia.state.set("request", { kind = kind, payload = payload })
  noctalia.state.set("request_rev", (tonumber(noctalia.state.get("request_rev")) or 0) + 1)
end

noctalia.state.watch("frame", function(value)
  frame = value
  render()
end)

noctalia.state.watch("status", function(value)
  status = value or "starting"
  statusMessage = noctalia.state.get("status_message") or ""
  render()
end)

function onOpen()
  open = true
  frame = noctalia.state.get("frame") or frame
  status = noctalia.state.get("status") or status
  statusMessage = noctalia.state.get("status_message") or ""
  render()
end

function onClose()
  open = false
end

function onSubmit(command)
  command = tostring(command or "")
  if noctalia.string.trim(command) == "" then
    return
  end

  request("run", command)
  inputKey += 1
  render()
end

-- Chords listed in plugin.toml arrive here while the panel holds focus.
function onKey(chord, pressed)
  if pressed then
    request("key", chord)
  end
end

function onScrollUp()
  request("scroll", -10)
end

function onScrollDown()
  request("scroll", 10)
end

function onRestart()
  request("restart")
end

function onOpenExternal()
  noctalia.runInTerminal("exec \"${SHELL:-sh}\"")
end

function onCloseClicked()
  panel.close()
end
