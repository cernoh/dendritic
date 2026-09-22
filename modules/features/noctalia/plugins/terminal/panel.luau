--!nonstrict
-- Renders the PTY screen as a clickable, themed dropdown terminal pane.

local FONT_SIZE = 13
local MAX_ROWS = 42
local MAX_RUNS = 64
local open = false
local focused = false
local frame = noctalia.state.get("frame")
local status = noctalia.state.get("status") or "starting"
local statusMessage = noctalia.state.get("status_message") or ""

local SHIFTED = { ["0"] = ")", ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", minus = "_", equal = "+", bracketleft = "{", bracketright = "}", backslash = "|", semicolon = ":", apostrophe = '"', comma = "<", period = ">", slash = "?", grave = "~" }
local PLAIN = { minus = "-", equal = "=", bracketleft = "[", bracketright = "]", backslash = "\\", semicolon = ";", apostrophe = "'", comma = ",", period = ".", slash = "/", grave = "`" }
local CONTROL_KEYS = { enter = true, tab = true, ["shift+tab"] = true, backspace = true, del = true, up = true, down = true, left = true, right = true, home = true, ["end"] = true, insert = true, ["ctrl+c"] = true, ["ctrl+d"] = true, ["ctrl+l"] = true, ["ctrl+u"] = true, ["ctrl+a"] = true, ["ctrl+e"] = true, ["ctrl+k"] = true, ["ctrl+w"] = true, ["ctrl+z"] = true, ["ctrl+shift+c"] = true, ["ctrl+shift+v"] = true }

local function textForChord(chord)
  if chord == "space" then return " " end
  if #chord == 1 then return chord end
  local shifted = string.match(chord, "^shift%+(.+)$")
  if shifted ~= nil then
    local byte = string.byte(shifted)
    if byte ~= nil and byte >= string.byte("a") and byte <= string.byte("z") then return string.char(byte - 32) end
    return SHIFTED[shifted]
  end
  return PLAIN[chord]
end

local function statusLabel()
  if status == "ready" then return "Running" end
  if status == "exited" then return "Shell exited" end
  if status == "unavailable" then return statusMessage ~= "" and statusMessage or "Backend unavailable" end
  return "Starting"
end

local function renderRun(run, index)
  local label = { key = "run-" .. tostring(index), text = tostring(run.t or ""), fontFamily = "monospace", fontSize = FONT_SIZE, color = run.f or (frame ~= nil and frame.dfg or "on_surface") }
  if run.b then label.fontWeight = "bold" end
  return ui.label(label)
end

local function renderScreen()
  local rows = {}
  if frame ~= nil and frame.L ~= nil then
    for index = 1, math.min(#frame.L, MAX_ROWS) do
      local row = frame.L[index]
      local children = {}
      if row == nil or #row == 0 then
        table.insert(children, ui.label({ text = " ", fontFamily = "monospace", fontSize = FONT_SIZE }))
      else
        for runIndex = 1, math.min(#row, MAX_RUNS) do table.insert(children, renderRun(row[runIndex], runIndex)) end
      end
      table.insert(rows, ui.row({ key = "row-" .. tostring(index), gap = 0 }, children))
    end
  end
  if #rows == 0 then table.insert(rows, ui.label({ text = "Waiting for the terminal…", color = "on_surface_variant" })) end
  return rows
end

local function request(kind, payload)
  noctalia.state.set("request", { kind = kind, payload = payload })
  noctalia.state.set("request_rev", (tonumber(noctalia.state.get("request_rev")) or 0) + 1)
end

local function render()
  if not open then return end
  local ready = status == "ready"
  panel.render(ui.column({ flexGrow = 1, gap = 8, padding = 10, fill = "surface", radius = 12, border = focused and "primary" or "outline", borderWidth = 0, onClick = "onTerminalClick" }, {
    ui.row({ align = "center", gap = 8, height = 26 }, {
      ui.glyph({ name = "terminal-2", size = 16, color = "primary" }),
      ui.label({ text = "Terminal", fontWeight = "bold", flexGrow = 1, color = "on_surface" }),
      ui.label({ text = statusLabel(), fontSize = 12, color = ready and "primary" or "on_surface_variant" }),
      ui.button({ glyph = "chevron-up", variant = "ghost", controlSize = "sm", tooltip = "Scroll back", enabled = ready, onClick = "onScrollUp" }),
      ui.button({ glyph = "chevron-down", variant = "ghost", controlSize = "sm", tooltip = "Scroll forward", enabled = ready, onClick = "onScrollDown" }),
      ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Restart shell", onClick = "onRestart" }),
      ui.button({ text = "Copy", variant = "ghost", controlSize = "sm", tooltip = "Copy terminal selection", enabled = ready, onClick = "onCopy" }),
      ui.button({ text = "Paste", variant = "ghost", controlSize = "sm", tooltip = "Paste clipboard text", enabled = ready, onClick = "onPaste" }),
      ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", tooltip = "Close", onClick = "onCloseClicked" }),
    }),
    ui.scroll({ key = "terminal-screen", flexGrow = 1, gap = 0, padding = 10, fill = "surface", radius = 8, border = "outline/0.7", borderWidth = 1, stickToBottom = true, onScroll = "onTerminalScroll", onClick = "onTerminalClick" }, renderScreen()),
  }))
end

noctalia.state.watch("frame", function(value) frame = value; render() end)
noctalia.state.watch("status", function(value) status = value or "starting"; statusMessage = noctalia.state.get("status_message") or ""; render() end)

function onOpen()
  open = true; focused = true
  frame = noctalia.state.get("frame") or frame
  status = noctalia.state.get("status") or status
  statusMessage = noctalia.state.get("status_message") or ""
  local geometry = noctalia.state.get("geometry")
  if geometry == nil or geometry.cols ~= 140 or geometry.rows ~= 42 then request("resize", "140x42") end
  render()
end

function onClose() open = false; focused = false end
function onTerminalClick() focused = true; render() end

function onKey(chord, pressed)
  if not pressed then return end
  if chord == "ctrl+shift+c" then request("copy"); return end
  if chord == "ctrl+shift+v" then request("paste"); return end
  if CONTROL_KEYS[chord] then request("key", chord); return end
  local text = textForChord(chord)
  if text ~= nil then request("text", text) end
end

function onCopy() request("copy") end
function onPaste() request("paste") end
function onTerminalScroll(axis, steps) if axis == "vertical" then request("scroll", tonumber(steps) or 0) end end
function onScrollUp() request("scroll", -10) end
function onScrollDown() request("scroll", 10) end
function onRestart() request("restart") end
function onCloseClicked() panel.close() end
