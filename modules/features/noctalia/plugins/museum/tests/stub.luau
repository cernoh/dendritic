--!nonstrict
-- Stub host for the museum plugin tests (PLAN 2.7).
--
-- Mirrors the five host namespaces the plugin can see — noctalia, ui,
-- barWidget, panel, shortcut — and records what the code did. Assert on the
-- tree, never on pixels. Run with:
--   nix shell nixpkgs#luau --command luau museum.luau
-- from this directory (a bare `luau` resolves require from the cwd, which is
-- why the modules are required without the .luau extension noctalia uses).

local S = {}

-- ── recorder ──────────────────────────────────────────────────────────────

S.rec = {
  rendered = nil, -- last tree handed to barWidget.render
  visible = nil,
  interval = nil,
  state = {},
  watchers = {},
  config = {},
  async = {}, -- argv tables passed to runAsync
  streams = {}, -- command strings passed to runStream
  streamHandlers = {},
  files = {},
  dirs = {},
  env = {},
  tr = {},
  clock = 0,
}

function S.reset()
  S.rec.rendered = nil
  S.rec.visible = nil
  S.rec.interval = nil
  S.rec.state = {}
  S.rec.watchers = {}
  S.rec.async = {}
  S.rec.streams = {}
  S.rec.streamHandlers = {}
end

function S.set(key, value)
  S.rec.state[key] = value
  local handlers = S.rec.watchers[key] or {}
  for _, fn in ipairs(handlers) do
    fn(value)
  end
end

-- ── a small JSON reader/writer ────────────────────────────────────────────
-- The host's is native; the tests only need the subset mmsg and the collector
-- emit. Keeping it here proves the fixtures are decoded, not hand-waved.

local function decodeString(text, index)
  local out = {}
  local i = index + 1
  while i <= #text do
    local char = string.sub(text, i, i)
    if char == '"' then
      return table.concat(out), i + 1
    elseif char == "\\" then
      local nextChar = string.sub(text, i + 1, i + 1)
      local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
      if nextChar == "u" then
        -- Fixtures carry no escapes; the native decoder is not under test.
        table.insert(out, "?")
        i = i + 6
      else
        table.insert(out, map[nextChar] or nextChar)
        i = i + 2
      end
    else
      table.insert(out, char)
      i = i + 1
    end
  end
  error("unterminated string")
end

local function decodeValue(text, index)
  while string.match(string.sub(text, index, index), "%s") do
    index = index + 1
  end
  local char = string.sub(text, index, index)
  if char == "{" then
    local object = {}
    index = index + 1
    while true do
      while string.match(string.sub(text, index, index), "%s") do
        index = index + 1
      end
      if string.sub(text, index, index) == "}" then
        return object, index + 1
      end
      if string.sub(text, index, index) == "," then
        index = index + 1
      end
      while string.match(string.sub(text, index, index), "%s") do
        index = index + 1
      end
      local key
      key, index = decodeString(text, index)
      while string.match(string.sub(text, index, index), "%s") do
        index = index + 1
      end
      index = index + 1 -- colon
      object[key], index = decodeValue(text, index)
    end
  elseif char == "[" then
    local array = {}
    index = index + 1
    while true do
      while string.match(string.sub(text, index, index), "%s") do
        index = index + 1
      end
      if string.sub(text, index, index) == "]" then
        return array, index + 1
      end
      if string.sub(text, index, index) == "," then
        index = index + 1
      end
      local value
      value, index = decodeValue(text, index)
      table.insert(array, value)
    end
  elseif char == '"' then
    return decodeString(text, index)
  elseif string.sub(text, index, index + 3) == "true" then
    return true, index + 4
  elseif string.sub(text, index, index + 4) == "false" then
    return false, index + 5
  elseif string.sub(text, index, index + 3) == "null" then
    return nil, index + 4
  else
    local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", index)
    if number == nil then
      error("bad json at " .. tostring(index))
    end
    return tonumber(number), index + #number
  end
end

local function decode(text)
  if text == nil then
    return nil
  end
  local ok, value = pcall(function()
    local parsed = decodeValue(text, 1)
    return parsed
  end)
  if not ok then
    return nil, value
  end
  return value
end

local function encodeValue(value)
  local kind = type(value)
  if kind == "nil" then
    return "null"
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "number" then
    return string.format("%.14g", value)
  elseif kind == "string" then
    return '"' .. string.gsub(value, '[%z\1-\31\\"]', function(char)
      local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
      return map[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
  elseif kind == "table" then
    local isArray = true
    local length = 0
    for key in pairs(value) do
      if type(key) ~= "number" then
        isArray = false
        break
      end
      length = math.max(length, key)
    end
    if isArray and length > 0 then
      local parts = {}
      for i = 1, length do
        table.insert(parts, encodeValue(value[i]))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do
      table.insert(keys, key)
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
      table.insert(parts, encodeValue(tostring(key)) .. ":" .. encodeValue(value[key]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

S.json = { decode = decode, encode = encodeValue }

-- ── noctalia.* ────────────────────────────────────────────────────────────

local noctalia = {}

function noctalia.setUpdateInterval(ms)
  S.rec.interval = ms
end

function noctalia.log() end

function noctalia.getConfig(key)
  return S.rec.config[key]
end

-- The Phase 1 palette document: the three museum materials ride at
-- dark.museum and are the only hexes the plugin is allowed to emit. Every test
-- process resolves them at module load, exactly like the live shell.
S.paletteJson = '{"dark":{"museum":{"brassLt":"#e2c08a","paper3":"#c8b58d","patina":"#7d9a8e"}},"light":{"museum":{"brassLt":"#8a6a3f","paper3":"#8a7a5f","patina":"#4f6a60"}}}'
S.rec.files["/home/tester/.config/noctalia/palettes/sepia.json"] = S.paletteJson

function noctalia.getSetting(path)
  if path == "theme.source" then
    return "custom"
  end
  if path == "theme.custom_palette" then
    return "sepia"
  end
  return nil
end

function noctalia.isDarkMode()
  return true
end

function noctalia.getenv(name)
  return S.rec.env[name]
end

function noctalia.expandPath(path)
  return string.gsub(path, "^~", "/home/tester")
end

function noctalia.tr(key)
  return S.rec.tr[key] or key
end

function noctalia.formatTime()
  return "15:15"
end

function noctalia.systemStats()
  return {
    cpu = { usagePercent = 9, tempC = 53 },
    ram = { usedMb = 6861, totalMb = 32000 },
    gpu = { usagePercent = 10 },
  }
end

function noctalia.readFile(path)
  return S.rec.files[path]
end

function noctalia.listDir(path)
  local dir = S.rec.dirs[path]
  if dir == nil then
    return nil, "not found"
  end
  return dir
end

function noctalia.fileInfo(path)
  return S.rec.files[path .. "::info"] or { mtime = 1, size = 1, isDir = false }
end

function noctalia.commandExists(name)
  return S.rec.commands == nil or S.rec.commands[name] ~= false
end

function noctalia.runAsync(argv, cb)
  table.insert(S.rec.async, argv)
  if cb ~= nil and S.rec.asyncResult ~= nil then
    local result = S.rec.asyncResult(argv)
    if result ~= nil then
      cb(result)
    end
  end
  return true
end

function noctalia.runStream(command, onLine)
  table.insert(S.rec.streams, command)
  table.insert(S.rec.streamHandlers, onLine)
  return true
end

noctalia.json = { decode = decode, encode = encodeValue }

noctalia.string = {
  trim = function(value)
    return (string.gsub(value or "", "^%s*(.-)%s*$", "%1"))
  end,
}

noctalia.state = {
  set = S.set,
  get = function(key)
    return S.rec.state[key]
  end,
  watch = function(key, fn)
    S.rec.watchers[key] = S.rec.watchers[key] or {}
    table.insert(S.rec.watchers[key], fn)
  end,
}

-- ── ui.* ──────────────────────────────────────────────────────────────────
-- Plain table taggers, exactly like the host prelude.

local ui = {}
local function ctor(kind)
  return function(props, children)
    return { type = kind, props = props or {}, children = children or {} }
  end
end

for _, kind in ipairs({
  "column",
  "row",
  "box",
  "label",
  "glyph",
  "image",
  "separator",
  "spacer",
  "progress",
  "button",
  "graph",
  "input",
  "markdown",
  "select",
  "slider",
  "toggle",
  "scroll",
}) do
  ui[kind] = ctor(kind)
end

-- ── entry globals ─────────────────────────────────────────────────────────

S.barWidget = {
  render = function(tree)
    S.rec.rendered = tree
  end,
  setVisible = function(visible)
    S.rec.visible = visible
  end,
  isVertical = function()
    return S.rec.vertical == true
  end,
  outputName = function()
    return S.rec.output or "DP-1"
  end,
}

S.noctalia = noctalia
S.ui = ui
S.panel = { render = function() end, close = function() end }
S.shortcut = { setLabel = function() end, setIcon = function() end }

-- The Luau CLI's global table is frozen, so a test installs the host by
-- assigning these to globals at its own top level:
--   noctalia = stub.noctalia; ui = stub.ui; barWidget = stub.barWidget
S.install = function()
  return nil
end

-- ── tree helpers ──────────────────────────────────────────────────────────

function S.count(tree, kind)
  if tree == nil then
    return 0
  end
  local n = tree.type == kind and 1 or 0
  for _, child in ipairs(tree.children or {}) do
    n = n + S.count(child, kind)
  end
  return n
end

function S.find(tree, predicate)
  if tree == nil then
    return nil
  end
  if predicate(tree) then
    return tree
  end
  for _, child in ipairs(tree.children or {}) do
    local hit = S.find(child, predicate)
    if hit ~= nil then
      return hit
    end
  end
  return nil
end

function S.findAll(tree, predicate, out)
  out = out or {}
  if tree == nil then
    return out
  end
  if predicate(tree) then
    table.insert(out, tree)
  end
  for _, child in ipairs(tree.children or {}) do
    S.findAll(child, predicate, out)
  end
  return out
end

-- Every color-ish prop value in the tree, in walk order.
function S.colors(tree, out)
  out = out or {}
  if tree == nil then
    return out
  end
  for _, prop in ipairs({ "color", "fill", "border", "track", "color2" }) do
    local value = tree.props[prop]
    if type(value) == "string" then
      table.insert(out, value)
    end
  end
  for _, child in ipairs(tree.children or {}) do
    S.colors(child, out)
  end
  return out
end

return S
