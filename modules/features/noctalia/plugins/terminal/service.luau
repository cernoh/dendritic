--!nonstrict
-- Keep one shell alive for the lifetime of the enabled plugin. The FIFO gives
-- the panel a command input path while runStream keeps shell output flowing.

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local dataDir = noctalia.pluginDataDir()
local fifo = dataDir and (dataDir .. "/input.fifo") or nil
local shell = noctalia.getenv("SHELL") or "/bin/sh"
local lastRevision = -1

local function appendOutput(line)
  line = tostring(line):gsub("\r", "")
  line = line:gsub("\27%[[0-9;?]*[ -/]*[@-~]", "")
  if line == "" then
    return
  end

  local output = noctalia.state.get("output") or ""
  output = output .. line .. "\n"
  if #output > 16000 then
    output = output:sub(-16000)
  end
  noctalia.state.set("output", output)
end

local function sendCommand(command)
  if fifo == nil or command == nil or command == "" then
    return false
  end

  local accepted = noctalia.runAsync(
    "printf '%s\\n' " .. shellQuote(command) .. " > " .. shellQuote(fifo)
  )
  if not accepted then
    noctalia.notifyError("Terminal", "Could not send the command to the shell")
  end
  return accepted
end

local function startShell()
  if fifo == nil or dataDir == nil then
    noctalia.state.set("status", "unavailable")
    noctalia.state.set("output", "Terminal could not create its persistent input pipe.\n")
    return
  end

  local shellCommand = shellQuote(shell) .. " -i"
  local runner = table.concat({
    "mkdir -p " .. shellQuote(dataDir),
    "(test -p " .. shellQuote(fifo) .. " || mkfifo " .. shellQuote(fifo) .. ")",
    "exec 3<> " .. shellQuote(fifo),
  }, " && ")
    .. " && while true; do "
    .. "if command -v script >/dev/null 2>&1; then "
    .. "script -qefc " .. shellQuote(shellCommand) .. " /dev/null <&3 2>&1; "
    .. "else " .. shellCommand .. " <&3 2>&1; "
    .. "fi; done"

  noctalia.state.set("status", "starting")
  noctalia.state.set("output", "Persistent shell ready.\n")
  if noctalia.runStream(runner, appendOutput) then
    noctalia.state.set("status", "ready")
  else
    noctalia.state.set("status", "unavailable")
    noctalia.state.set("output", "Terminal could not start the shell runner.\n")
  end
end

noctalia.state.watch("input_revision", function(value)
  local revision = tonumber(value) or 0
  if revision == lastRevision then
    return
  end
  lastRevision = revision
  sendCommand(noctalia.state.get("input"))
end)

function onIpc(event, payload)
  if event == "run" then
    sendCommand(payload)
  elseif event == "clear" then
    noctalia.state.set("output", "")
  elseif event == "restart" then
    startShell()
  end
end

startShell()
