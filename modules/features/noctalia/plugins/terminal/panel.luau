--!nonstrict
-- Renders the screen the service publishes, and hands every key to the shell.
--
-- The panel is the terminal window rather than a terminal inside a window: no
-- header, no command entry, no scrollbar. The shell owns the prompt, the
-- cursor and the scrollback; the Noctalia palette owns every color; the only
-- chrome is the restart button a real terminal also shows once its shell is
-- gone. A chord arrives here only because plugin.toml declared it, so the
-- printable set is spelled out in TEXT below and every entry in capture_keys
-- must have a line there or in KEYS.

local FONT_SIZE = 13
local MAX_ROWS = 40
local MAX_RUNS = 64
-- Pixels one terminal line takes at FONT_SIZE, used to turn a wheel delta in
-- the scroll view into a row count for the shell.
local ROW_HEIGHT = 18

-- Every printable chord the panel captures, mapped to the character it types.
local TEXT = {
  ["a"] = "a",
  ["b"] = "b",
  ["c"] = "c",
  ["d"] = "d",
  ["e"] = "e",
  ["f"] = "f",
  ["g"] = "g",
  ["h"] = "h",
  ["i"] = "i",
  ["j"] = "j",
  ["k"] = "k",
  ["l"] = "l",
  ["m"] = "m",
  ["n"] = "n",
  ["o"] = "o",
  ["p"] = "p",
  ["q"] = "q",
  ["r"] = "r",
  ["s"] = "s",
  ["t"] = "t",
  ["u"] = "u",
  ["v"] = "v",
  ["w"] = "w",
  ["x"] = "x",
  ["y"] = "y",
  ["z"] = "z",
  ["A"] = "A",
  ["B"] = "B",
  ["C"] = "C",
  ["D"] = "D",
  ["E"] = "E",
  ["F"] = "F",
  ["G"] = "G",
  ["H"] = "H",
  ["I"] = "I",
  ["J"] = "J",
  ["K"] = "K",
  ["L"] = "L",
  ["M"] = "M",
  ["N"] = "N",
  ["O"] = "O",
  ["P"] = "P",
  ["Q"] = "Q",
  ["R"] = "R",
  ["S"] = "S",
  ["T"] = "T",
  ["U"] = "U",
  ["V"] = "V",
  ["W"] = "W",
  ["X"] = "X",
  ["Y"] = "Y",
  ["Z"] = "Z",
  ["0"] = "0",
  ["1"] = "1",
  ["2"] = "2",
  ["3"] = "3",
  ["4"] = "4",
  ["5"] = "5",
  ["6"] = "6",
  ["7"] = "7",
  ["8"] = "8",
  ["9"] = "9",
  ["minus"] = "-",
  ["equal"] = "=",
  ["bracketleft"] = "[",
  ["bracketright"] = "]",
  ["backslash"] = "\\",
  ["semicolon"] = ";",
  ["apostrophe"] = "'",
  ["grave"] = "`",
  ["comma"] = ",",
  ["period"] = ".",
  ["slash"] = "/",
  ["space"] = " ",
  ["exclam"] = "!",
  ["quotedbl"] = "\"",
  ["numbersign"] = "#",
  ["dollar"] = "$",
  ["percent"] = "%",
  ["ampersand"] = "&",
  ["parenleft"] = "(",
  ["parenright"] = ")",
  ["asterisk"] = "*",
  ["plus"] = "+",
  ["colon"] = ":",
  ["less"] = "<",
  ["greater"] = ">",
  ["question"] = "?",
  ["at"] = "@",
  ["asciicircum"] = "^",
  ["underscore"] = "_",
  ["braceleft"] = "{",
  ["bar"] = "|",
  ["braceright"] = "}",
  ["asciitilde"] = "~",
}

-- Chords the helper's key table knows under a different name.
local KEYS = {
  page_up = "pageup",
  page_down = "pagedown",
  ["return"] = "enter",
}

local open = false
local frame = noctalia.state.get("frame")
local status = noctalia.state.get("status") or "starting"
local statusMessage = noctalia.state.get("status_message") or ""
local lastScrollOffset = nil

local function defaultForeground()
  if frame ~= nil and frame.dfg ~= nil then
    return frame.dfg
  end
  return "on_surface"
end

local function background()
  if frame ~= nil and frame.dbg ~= nil then
    return frame.dbg
  end
  return "surface_container_lowest"
end

-- Post work to the service. The revision counter makes two identical requests
-- in a row both run, which a bare value comparison would swallow.
local function request(kind, payload)
  noctalia.state.set("request", { kind = kind, payload = payload })
  noctalia.state.set("request_rev", (tonumber(noctalia.state.get("request_rev")) or 0) + 1)
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

-- A click on a line copies it. Noctalia's plugin UI has no pointer press or
-- drag callback, so a free selection across cells cannot be drawn; the line is
-- the finest thing one click can name, and the service owns the clipboard.
local function renderRow(row, index)
  local props = {
    key = "row-" .. tostring(index),
    gap = 0,
    onClick = function()
      request("copyline", index)
    end,
  }

  if row == nil or #row == 0 then
    -- A blank terminal line still occupies a line, so give it one.
    return ui.row(props, {
      ui.label({ text = " ", fontFamily = "monospace", fontSize = FONT_SIZE }),
    })
  end

  local children = {}
  for runIndex = 1, math.min(#row, MAX_RUNS) do
    table.insert(children, renderRun(row[runIndex], runIndex))
  end
  return ui.row(props, children)
end

local function renderScreen()
  local rows = {}
  if frame ~= nil and frame.L ~= nil then
    for index = 1, math.min(#frame.L, MAX_ROWS) do
      table.insert(rows, renderRow(frame.L[index], index))
    end
  end
  return rows
end

-- Shown instead of the screen while the shell is missing or gone.
local function renderNotice()
  local message = statusMessage
  if message == "" then
    message = status == "exited" and noctalia.tr("status.exited") or noctalia.tr("status.starting")
  end

  local children = {
    ui.label({ text = message, color = "on_surface_variant", fontSize = 13 }),
  }
  if status == "exited" then
    table.insert(children, ui.button({
      text = noctalia.tr("button.restart"),
      variant = "secondary",
      onClick = "onRestart",
    }))
  end
  return children
end

local function render()
  if not open then
    return
  end

  local fill = background()
  panel.render(ui.column({
    flexGrow = 1,
    padding = 0,
    fill = fill,
    radius = 12,
    border = "outline",
    borderWidth = 1,
  }, {
    ui.scroll({
      flexGrow = 1,
      gap = 0,
      padding = 10,
      fill = fill,
      -- Follow new output, but release the pin when the user scrolls away.
      -- Forcing the bottom on every frame would make history unreadable while
      -- a command is still writing.
      stickToBottom = true,
      onScroll = "onScroll",
    }, status == "ready" and renderScreen() or renderNotice()),
  }))
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
  lastScrollOffset = nil
  -- The palette is read per open, so a theme change reaches the terminal
  -- without restarting the shell.
  request("theme")
  render()
end

function onClose()
  open = false
end

-- Chords listed in plugin.toml arrive here while the panel holds focus.
function onKey(chord, pressed)
  if not pressed or status ~= "ready" then
    return
  end

  local text = TEXT[chord]
  if text == nil and string.sub(chord, 1, 6) == "shift+" then
    -- A shifted character arrives either as its own keysym ("exclam") or as
    -- the unshifted keysym with Shift still in the modifier set. Both type
    -- the same character; "shift+tab" has no TEXT entry and stays a key.
    text = TEXT[string.sub(chord, 7)]
  end

  if text ~= nil then
    request("type", text)
  else
    request("key", KEYS[chord] or chord)
  end
end

-- The wheel belongs to the shell, so the panel only reports the delta.
function onScroll(offset)
  local current = tonumber(offset) or 0
  if lastScrollOffset ~= nil then
    local rows = math.floor((current - lastScrollOffset) / ROW_HEIGHT)
    if rows ~= 0 then
      request("scroll", rows)
    end
  end
  lastScrollOffset = current
end

function onRestart()
  request("restart")
end
