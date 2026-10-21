--!nonstrict
-- Mango compositor bridge for the museum bar.
--
-- The plugin API exposes no workspace or active-window state (noctalia 5.3.0,
-- plugin_api 34), so halls and the wall label read Mango's own IPC. The
-- compositor is the source of truth anyway: `mmsg watch all-tags` and
-- `mmsg watch focusing-client` both emit a full JSON object per change, and
-- focusing-client also re-emits when the focused client's title changes.
--
-- `MANGO_INSTANCE_SIGNATURE` is in the noctalia user service's environment.
-- The socket scan is the fallback for a shell started outside `exec-once`.

local M = {}

local function shellQuote(value)
  return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

function M.socket()
  local signature = noctalia.getenv("MANGO_INSTANCE_SIGNATURE")
  if signature ~= nil and signature ~= "" then
    return signature
  end

  local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
  if runtime == nil or runtime == "" then
    return nil
  end
  local names = noctalia.listDir(runtime)
  if names == nil then
    return nil
  end

  local best, bestMtime = nil, nil
  for _, name in ipairs(names) do
    if string.match(name, "^mango%-%d+%.sock$") ~= nil then
      local path = runtime .. "/" .. name
      local info = noctalia.fileInfo(path)
      local mtime = info and info.mtime or 0
      if best == nil or mtime > bestMtime then
        best, bestMtime = path, mtime
      end
    end
  end
  return best
end

-- A shell command for noctalia.runStream, which takes a string only. The
-- signature is a local socket path, so it is quoted rather than trusted.
function M.streamCommand(socket, args)
  local parts = { "MANGO_INSTANCE_SIGNATURE=" .. shellQuote(socket), "mmsg" }
  for _, arg in ipairs(args) do
    table.insert(parts, shellQuote(arg))
  end
  return table.concat(parts, " ")
end

local function argv(socket, args)
  local out = { "env", "MANGO_INSTANCE_SIGNATURE=" .. socket, "mmsg" }
  for _, arg in ipairs(args) do
    table.insert(out, arg)
  end
  return out
end

-- One-shot query: cb(decoded) or cb(nil) when the socket, mmsg, or JSON fails.
function M.get(args, cb)
  local socket = M.socket()
  if socket == nil then
    cb(nil)
    return false
  end
  return noctalia.runAsync(argv(socket, args), function(result)
    if result == nil or result.exitCode ~= 0 then
      cb(nil)
      return
    end
    local data = noctalia.json.decode(result.stdout)
    cb(data)
  end)
end

-- A persistent `mmsg watch`. Returns false when there is no socket to watch.
function M.watch(args, onData)
  local socket = M.socket()
  if socket == nil then
    return false
  end
  return noctalia.runStream(M.streamCommand(socket, args), function(line)
    if line == nil or line == "" then
      return
    end
    local data = noctalia.json.decode(line)
    if data ~= nil then
      onData(data)
    end
  end)
end

-- Switch one monitor to a tag. viewcrossmon focuses the named monitor and
-- views the tag on it in a single dispatch, so the click is atomic.
function M.viewTag(monitor, index)
  if monitor == nil or monitor == "" then
    return M.dispatch({ "view," .. tostring(index) })
  end
  return M.dispatch({ "viewcrossmon," .. tostring(index) .. "," .. monitor })
end

function M.dispatch(args)
  local socket = M.socket()
  if socket == nil then
    return false
  end
  return noctalia.runAsync(argv(socket, { "dispatch", table.concat(args, ",") }))
end

-- Run a noctalia IPC command (`msg` verb + arguments). Used by the tray for
-- panel navigation, and by nothing else: the museum must not re-implement the
-- shell's own controls.
function M.msg(...)
  local args = { "noctalia", "msg" }
  for _, value in ipairs({ ... }) do
    table.insert(args, value)
  end
  return noctalia.runAsync(args)
end

-- Pick the tag list a bar on `monitor` should show, honouring
-- `hide_when_empty` (the built-in workspaces widget's behaviour).
function M.hallTags(allTags, monitor, count, hideEmpty)
  if allTags == nil or allTags.all_tags == nil then
    return {}, monitor
  end

  local chosen = nil
  for _, entry in ipairs(allTags.all_tags) do
    if monitor ~= nil and entry.monitor == monitor then
      chosen = entry
      break
    end
  end
  if chosen == nil then
    for _, entry in ipairs(allTags.all_tags) do
      for _, tag in ipairs(entry.tags or {}) do
        if tag.is_active then
          chosen = entry
          break
        end
      end
      if chosen ~= nil then
        break
      end
    end
  end
  if chosen == nil then
    chosen = allTags.all_tags[1]
  end
  if chosen == nil then
    return {}, monitor
  end

  local out = {}
  for _, tag in ipairs(chosen.tags or {}) do
    local under = count == nil or count <= 0 or tag.index <= count
    local populated = tag.is_active or (tag.client_count or 0) > 0
    if under and (not hideEmpty or populated) then
      table.insert(out, tag)
    end
  end
  return out, chosen.monitor
end

return M
