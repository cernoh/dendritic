--!nonstrict
-- Drives the ghostty-term helper and publishes its frames as plugin state.
--
-- The helper owns the pseudo-terminal and a libghostty-vt terminal. It writes
-- one JSON frame per screen change on stdout, and reads commands from a FIFO.
-- This service is the only writer of that FIFO, so panels and widgets never
-- touch the helper directly.
--
-- Entries exchange plain values through noctalia.state, so the panel posts work
-- to the "request" key and bumps "request_rev". A counter is necessary because
-- two identical requests in a row must still both run.
--
-- Frame shape (one JSON object per line):
--   {"t":"f","s":<seq>,"c":<cols>,"r":<rows>,
--    "dfg":"#rrggbb","dbg":"#rrggbb",
--    "L":[[{"t":"text","f":"#rrggbb","b":true}, ...], ...]}

local COLS = 100
local ROWS = 28

local dataDir = noctalia.pluginDataDir()
local fifo = dataDir and (dataDir .. "/term.fifo") or nil
local shell = noctalia.getenv("SHELL") or "/bin/sh"
local ready = false
local lastSequence = -1
local lastRequestRevision = 0

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function setStatus(status, message)
  noctalia.state.set("status", status)
  noctalia.state.set("status_message", message or "")
end

local function blankFrame()
  -- Sepia colors, copied from modules/features/scheme/default.nix. The Luau
  -- sandbox cannot read the palette, so a palette change needs this edit.
  return { t = "f", s = 0, c = COLS, r = ROWS, dfg = "#ece0cd", dbg = "#1e1813", L = {} }
end

-- Write one command line to the helper. The helper reads commands from the FIFO
-- until a newline, so a newline that must reach the shell travels as the
-- two-character escape \n.
local function send(command)
  if fifo == nil then
    return false
  end
  if not ready then
    noctalia.notifyError("Terminal", "The terminal backend is not running.")
    return false
  end

  local accepted = noctalia.runAsync(
    "printf '%s\\n' " .. shellQuote(command) .. " > " .. shellQuote(fifo)
  )
  if not accepted then
    noctalia.notifyError("Terminal", "Could not reach the terminal backend.")
  end
  return accepted
end

-- Escape text for the helper's `i` command. The backslash goes first, so the
-- escapes added here are not escaped a second time.
local function escapeText(text)
  text = text:gsub("\\", "\\\\")
  text = text:gsub("\r", "\\r")
  text = text:gsub("\n", "\\n")
  text = text:gsub("\t", "\\t")
  return text
end

local function handleLine(line)
  if line == nil or line == "" then
    return
  end

  local frame = noctalia.json.decode(line)
  if frame == nil then
    return
  end

  if frame.t == "init" then
    noctalia.state.set("geometry", { cols = frame.c, rows = frame.r })
    return
  end

  if frame.t == "exit" then
    ready = false
    setStatus("exited", "The shell exited. Use Restart to open a new one.")
    return
  end

  if frame.t ~= "f" then
    return
  end

  -- Frames arrive in order. Drop one if it ever arrives late.
  local sequence = tonumber(frame.s) or 0
  if sequence <= lastSequence then
    return
  end
  lastSequence = sequence

  noctalia.state.set("frame", frame)
end

local function startHelper()
  if fifo == nil then
    setStatus("unavailable", "The plugin data directory is not writable.")
    return
  end

  if not noctalia.commandExists("ghostty-term") then
    setStatus("unavailable", "The ghostty-term helper is not on PATH.")
    noctalia.notifyError("Terminal", "The ghostty-term helper is not installed.")
    return
  end

  setStatus("starting", "")
  noctalia.state.set("frame", blankFrame())

  local command = table.concat({
    "mkdir -p " .. shellQuote(dataDir),
    "exec ghostty-term "
      .. shellQuote(fifo)
      .. " "
      .. tostring(COLS)
      .. " "
      .. tostring(ROWS)
      .. " "
      .. shellQuote(shell),
  }, " && ")

  if noctalia.runStream(command, handleLine) then
    ready = true
    lastSequence = -1
    setStatus("ready", "")
  else
    setStatus("unavailable", "The terminal backend did not start.")
  end
end

-- The panel posts work here. Each request carries a kind and an optional
-- payload, so adding a command needs no new state key.
local function handleRequest(request)
  if request == nil then
    return
  end

  local kind = request.kind
  local payload = request.payload

  if kind == "run" then
    send("i" .. escapeText(tostring(payload or "")) .. "\\n")
  elseif kind == "key" then
    send("k" .. tostring(payload or ""))
  elseif kind == "scroll" then
    send("s" .. tostring(tonumber(payload) or 0))
  elseif kind == "resize" then
    send("z" .. tostring(payload or ""))
  elseif kind == "restart" then
    ready = false
    startHelper()
  end
end

noctalia.state.watch("request_rev", function(value)
  local revision = tonumber(value) or 0
  if revision == lastRequestRevision then
    return
  end
  lastRequestRevision = revision
  handleRequest(noctalia.state.get("request"))
end)

startHelper()
