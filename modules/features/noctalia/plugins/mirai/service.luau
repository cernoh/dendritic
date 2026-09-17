--!nonstrict
-- Drives the `mirai` CLI for every other entry of this plugin.
--
-- Mirai keeps its state in a daemon that serves a JSON socket, and `mirai` is
-- the client for that socket. The plugin never speaks the socket itself: this
-- service runs the CLI, publishes the parsed answer on "snapshot", and answers
-- the work the panel posts on "request".
--
-- Entries exchange plain values only, so the panel posts a kind and a payload
-- and bumps "request_rev". The counter is required: two identical requests in a
-- row must both run, which a bare value comparison would swallow.

local BIN = noctalia.getConfig("binary") or "mirai"
local SOCKET = noctalia.getConfig("socket") or ""
local POLL_MS = math.max(1, tonumber(noctalia.getConfig("poll_seconds")) or 2) * 1000
local SCAN_SECONDS = math.max(3, tonumber(noctalia.getConfig("scan_seconds")) or 10)

-- How long a start action may hold the panel busy before the service stops
-- waiting for the daemon to answer.
local START_TIMEOUT_MS = 8000

-- Session variables the sink player needs to draw on this desktop. `sudo`
-- drops them, so the root route passes them through `env` explicitly.
local SESSION_VARS = {
  "WAYLAND_DISPLAY",
  "XDG_RUNTIME_DIR",
  "XDG_SESSION_TYPE",
  "DBUS_SESSION_BUS_ADDRESS",
  "XDG_CURRENT_DESKTOP",
}

local installed = false
local inFlight = false
local lastRequestRevision = 0
local shareDisplay = ""
local busySince = nil
-- What the running action waits for: "up" for a daemon start, "down" for a
-- daemon stop. A nil goal means the CLI answer itself ends the action.
local busyGoal = nil
-- True while the published message came from a poll, so the next good poll can
-- clear it without wiping the answer of an action.
local messageFromPoll = false

local function setMessage(text)
  noctalia.state.set("message", text or "")
end

local function setBusy(token, goal)
  noctalia.state.set("busy", token or "")
  busySince = (token ~= nil and token ~= "") and noctalia.nowMs() or nil
  busyGoal = busySince ~= nil and goal or nil
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- The socket override travels in the environment, so the command runs through
-- `env`. The argument form keeps every value out of a shell.
local function argv(args)
  local out = {}
  if SOCKET ~= "" then
    table.insert(out, "env")
    table.insert(out, "MIRAI_SOCK=" .. SOCKET)
  end
  table.insert(out, BIN)
  for _, value in ipairs(args) do
    table.insert(out, value)
  end
  return out
end

local function commandPresent(name)
  if name:find("/", 1, true) ~= nil then
    return noctalia.fileExists(name)
  end
  return noctalia.commandExists(name)
end

local function firstLine(text)
  if text == nil then
    return nil
  end
  local line = tostring(text):match("^%s*([^\n]*)") or ""
  line = noctalia.string.trim(line)
  if line == "" then
    return nil
  end
  return line
end

-- Every Mirai request answers with one JSON object. A command that needs a
-- running daemon exits 1 and explains itself on stdout instead.
local function response(result)
  if result == nil then
    return nil
  end
  local payload = noctalia.json.decode(result.stdout or "")
  if payload ~= nil then
    return payload
  end
  return nil, firstLine(result.stdout) or firstLine(result.stderr)
end

-- Trim the daemon answer to what the entries render. The panel never sees the
-- raw response, so the payload it copies stays small.
local function snapshotFrom(result)
  local snapshot = { installed = true, running = false }
  local payload, plain = response(result)

  if payload == nil or payload.ok ~= true then
    snapshot.message = plain or (payload ~= nil and payload.error or nil)
    return snapshot
  end

  local sink = payload.sink or {}
  local source = payload.source or {}

  snapshot.running = true
  snapshot.version = payload.version
  snapshot.mode = payload.mode
  snapshot.sink = {
    running = sink.running == true,
    mode = sink.mode,
    player_running = sink.player_running == true,
    friendly_name = sink.friendly_name,
    links = sink.links or {},
    peers = sink.peers or {},
  }
  snapshot.source = {
    scanning = source.scanning == true,
    streaming = source.streaming == true,
    sinks = source.sinks or {},
    current = source.current_sink,
    display = source.display,
  }
  snapshot.displays = payload.displays or {}
  return snapshot
end

local function publish(snapshot)
  noctalia.state.set("snapshot", snapshot)
end

local function refresh()
  if not installed or inFlight then
    return
  end

  inFlight = true
  local accepted = noctalia.runAsync(argv({ "status" }), function(result)
    inFlight = false
    local snapshot = snapshotFrom(result)
    publish(snapshot)

    if snapshot.running then
      if busySince ~= nil and (busyGoal == nil or busyGoal == "up") then
        setBusy(nil)
      end
      -- The daemon answers again, so a message the poll wrote is stale.
      if messageFromPoll then
        setMessage(nil)
        messageFromPoll = false
      end
      return
    end

    if busyGoal == "down" then
      -- `mirai quit` stops the daemon before it answers, so the CLI exits with
      -- an error. The poll is the confirmation that the stop worked.
      setBusy(nil)
      setMessage(nil)
      return
    end

    setMessage(snapshot.message or noctalia.tr("error.no_answer"))
    messageFromPoll = true
  end)

  if accepted == false then
    inFlight = false
    setMessage(noctalia.tr("error.cannot_run", { binary = BIN }))
  end
end

-- Every command ends here: report the refusal, then show the new state.
local function finish(result)
  setBusy(nil)
  messageFromPoll = false
  local payload = response(result)
  if payload ~= nil and payload.ok == false then
    local text = tostring(payload.error or noctalia.tr("error.refused"))
    setMessage(text)
    noctalia.state.set("needs_root", text:lower():find("root", 1, true) ~= nil)
  else
    setMessage("")
    noctalia.state.set("needs_root", false)
  end
  refresh()
end

local function startWithRoot()
  -- Sink mode needs a root daemon, and sudo needs a terminal for the password.
  -- `sudo` and `env` stay unquoted: they are literals, and every value that
  -- follows is quoted.
  local parts = {}
  if SOCKET ~= "" then
    table.insert(parts, "MIRAI_SOCK=" .. shellQuote(SOCKET))
  end
  for _, name in ipairs(SESSION_VARS) do
    local value = noctalia.getenv(name)
    if value ~= nil and value ~= "" then
      table.insert(parts, name .. "=" .. shellQuote(value))
    end
  end
  table.insert(parts, shellQuote(BIN))
  table.insert(parts, "daemon")
  table.insert(parts, "--foreground")

  noctalia.runInTerminal("sudo env " .. table.concat(parts, " "))
end

local function handle(request)
  if request == nil then
    return
  end

  local kind = request.kind
  local payload = request.payload

  if kind == "refresh" then
    refresh()
  elseif kind == "scan" then
    setBusy("scan")
    noctalia.runAsync(argv({ "source-scan", "--timeout", tostring(SCAN_SECONDS) }), finish)
  elseif kind == "connect" then
    setBusy("connect")
    local args = { "source-connect", tostring(payload or "") }
    if shareDisplay ~= "" then
      table.insert(args, "--display")
      table.insert(args, shareDisplay)
    end
    noctalia.runAsync(argv(args), finish)
  elseif kind == "disconnect" then
    setBusy("connect")
    noctalia.runAsync(argv({ "source-disconnect" }), finish)
  elseif kind == "display" then
    shareDisplay = tostring(payload or "")
    noctalia.runAsync(argv({ "source-display", shareDisplay ~= "" and shareDisplay or "default" }), finish)
  elseif kind == "sink_start" then
    setBusy("sink")
    noctalia.runAsync(argv({ "sink-start" }), finish)
  elseif kind == "sink_stop" then
    setBusy("sink")
    noctalia.runAsync(argv({ "sink-stop" }), finish)
  elseif kind == "sink_mode" then
    noctalia.runAsync(argv({ "sink-mode", tostring(payload or "window") }), finish)
  elseif kind == "stop_all" then
    setBusy("sink")
    noctalia.runAsync(argv({ "stop" }), finish)
  elseif kind == "daemon_start" then
    setBusy("daemon", "up")
    -- `mirai daemon` backgrounds the daemon itself and returns at once.
    noctalia.runAsync(argv({ "daemon" }))
    refresh()
  elseif kind == "daemon_stop" then
    -- The daemon exits before it answers `quit`, so the CLI reports an error
    -- for a stop that worked. Wait for the poll instead of trusting the answer.
    setBusy("daemon", "down")
    messageFromPoll = false
    setMessage(nil)
    noctalia.state.set("needs_root", false)
    noctalia.runAsync(argv({ "quit" }))
    refresh()
  elseif kind == "daemon_root" then
    startWithRoot()
  end
end

installed = commandPresent(BIN)
noctalia.setUpdateInterval(POLL_MS)

noctalia.state.watch("request_rev", function(value)
  local revision = tonumber(value) or 0
  if revision == lastRequestRevision then
    return
  end
  lastRequestRevision = revision
  handle(noctalia.state.get("request"))
end)

if installed then
  noctalia.state.set("needs_root", false)
  publish({ installed = true, running = false })
  refresh()
else
  publish({ installed = false })
end

function update()
  if busySince ~= nil and noctalia.nowMs() - busySince > START_TIMEOUT_MS then
    setBusy(nil)
    setMessage(noctalia.tr("error.timeout"))
  end
  refresh()
end

function onEnable()
  refresh()
end
