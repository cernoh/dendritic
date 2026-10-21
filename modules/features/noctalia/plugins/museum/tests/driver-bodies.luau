--!nonstrict
-- Every catalogue-drawer body, in every state it can be opened in
-- (Issue 6 / PLAN 2.7). Assembled and run by ../../../tests/run-museum-tests.sh.
--
-- driver-panel.luau proves the content of each section against one rich feed.
-- This driver proves the *body contract* for all ten wings, twice:
--
--   * populated — every section renders its own body from a complete feed;
--   * unlit     — with every feed empty the section still renders a body, so a
--                 blank wing is a bug and not an empty state;
--
-- and validates both trees against the host reconciler (`stub.validate`): a
-- known control, a known prop per control, no box with children, and a color
-- that is a role token or one of the three allowed palette hexes.

-- ── fixtures ──────────────────────────────────────────────────────────────

do
  local decoded, err = stub.json.decode(__translationsJson)
  assert(decoded ~= nil, "translations/en.json decodes: " .. tostring(err))
  stub.rec.tr = decoded
end

stub.noctalia.getSetting = function(path)
  return ({
    ["location.address"] = "NixPC, Study",
    ["location.auto_locate"] = false,
    ["location.sunrise"] = "07:12",
    ["location.sunset"] = "18:02",
    ["calendar.enabled"] = false,
  })[path]
end

stub.noctalia.systemStats = function()
  return {
    cpu = { usagePercent = 13, tempC = 66 },
    ram = { usagePercent = 38, usedMb = 12185, totalMb = 32000 },
    swap = { usedMb = 1024, totalMb = 9000 },
    gpu = { usagePercent = 44, tempC = 46, vramUsedBytes = 3435973836 },
    net = { rxBytesPerSec = 4200, txBytesPerSec = 128 },
    loadAvg = { 5.59, 7.78, 7.37 },
  }
end

stub.noctalia.outputs = function()
  return {
    { name = "DP-1", description = "AOC 24G2W1G3", width = 1920, height = 1080, x = 0, y = 0, scale = 1, focused = true },
    { name = "DP-2", description = "Huawei AD80HW", width = 1920, height = 1080, x = 1920, y = 0, scale = 1 },
  }
end

stub.noctalia.diskMounts = function()
  return { { path = "/", source = "/dev/nvme0n1p2", filesystem = "btrfs" } }
end

stub.noctalia.diskStats = function()
  return { usagePercent = 52, totalBytes = 489600000000, freeBytes = 235000000000 }
end

stub.set("drawer", {
  maker = "AMD Ryzen 7 3700X",
  gpu = "NVIDIA GeForce RTX 3060",
  origin = "NixOS 26.11 (Xanthe)",
  substrate = "7.2.11",
  frame = "mango",
  hostname = "NIXPC",
  uptime = 6420,
  supplies = { { name = "hidpp_battery_0", kind = "Battery", capacity = 100, status = "Discharging" } },
  profile = "performance",
  audio = {
    sink = { name = "AB13X Headset Adapter Analog Stereo", volume = 0.53, muted = false },
    source = { name = "USB PnP Audio Device Mono", volume = 1.0, muted = true },
    apps = { { name = "Brave", volume = 1.0, muted = false } },
  },
  wired = { name = "enp5s0", state = "connected" },
  wireless = { name = "wlp4s0", state = "disconnected" },
  addresses = { enp5s0 = "192.168.1.121" },
  networks = {
    { ssid = "Onecom_5EF2", signal = 90 },
    { ssid = "SKYXFXSL", signal = 49 },
  },
  bt = {
    powered = true,
    discoverable = false,
    paired = { { address = "AA:BB:CC:DD:EE:FF", name = "DualSense Wireless Controller" } },
    connected = {},
  },
  media = {
    player = "brave",
    app = "Brave",
    title = "(3) Meet the Gruutmans - YouTube",
    artist = "",
    length = 3766501000,
    position = 1305433229,
    status = "Paused",
  },
})

stub.set("notifications", {
  { title = "Done in 17m 41s", app = "Terminal", body = "nixos-rebuild switch", age_days = 1, stamp = "filed" },
})

local waveform = {}
for index = 1, 32 do
  waveform[index] = index / 32
end
stub.set("bands", waveform)
stub.set("unread", 2)

-- ── helpers ───────────────────────────────────────────────────────────────

local rendered

panel.render = function(tree)
  rendered = tree
end
panel.close = function() end
panel.setWantsSecondTicks = function() end

local WINGS = {
  "system",
  "power",
  "audio",
  "display",
  "network",
  "bluetooth",
  "weather",
  "calendar",
  "notices",
  "media",
}

local function findKey(tree, key)
  return stub.find(tree, function(node)
    return node.props.key == key
  end)
end

local function nodeCount(tree)
  if tree == nil then
    return 0
  end
  local count = 1
  for _, child in ipairs(tree.children or {}) do
    count = count + nodeCount(child)
  end
  return count
end

local allowedHex = {}
for _, hex in ipairs(museum.hexExceptions) do
  allowedHex[hex] = true
end

-- One wing's body, validated. `state` names the pass so a failure says which.
local function checkBody(id, state)
  local section = findKey(rendered, "section-" .. id)
  assert(section ~= nil, id .. ": the section body renders (" .. state .. ")")
  assert(nodeCount(section) >= 4, id .. ": the body is not a blank column (" .. state .. ")")
  stub.validate(rendered, id .. "/" .. state)
  for _, color in ipairs(stub.colors(section)) do
    if string.sub(color, 1, 1) == "#" then
      assert(allowedHex[color], id .. ": unexpected hex " .. color .. " (" .. state .. ")")
    else
      assert(
        string.match(color, "^[%a_][%w_]*$") or string.match(color, "^[%a_][%w_]*/%d+%.?%d*$"),
        id .. ": color is a role or a role/alpha, got " .. color .. " (" .. state .. ")"
      )
    end
  end
end

local function openWing(id)
  local row = findKey(rendered, "rail-" .. id)
  assert(row ~= nil, id .. ": the rail entry exists")
  row.props.onClick()
end

-- ── populated: every body draws its record ────────────────────────────────

onOpen()
assert(rendered ~= nil, "the drawer renders on open")
assert(rendered.props.key == "museum-drawer", "the drawer root is keyed")

for _, id in ipairs(WINGS) do
  openWing(id)
  checkBody(id, "populated")
end

-- The body is a scroll container keyed per wing, so a section switch replaces
-- the body rather than appending to it.
openWing("system")
assert(findKey(rendered, "body-system") ~= nil, "the system body is keyed")
openWing("media")
assert(findKey(rendered, "body-system") == nil, "switching wings replaces the body")
assert(findKey(rendered, "body-media") ~= nil, "the media body is keyed")

-- ── unlit: every body still renders an empty state ────────────────────────

stub.set("drawer", nil)
stub.set("notifications", nil)
stub.set("bands", nil)
stub.set("unread", nil)
stub.noctalia.systemStats = function()
  return nil
end
stub.noctalia.outputs = function()
  return {}
end
stub.noctalia.diskMounts = function()
  return {}
end
stub.noctalia.diskStats = function()
  return nil
end
stub.noctalia.getSetting = function()
  return nil
end

onOpen()
for _, id in ipairs(WINGS) do
  openWing(id)
  checkBody(id, "unlit")
end

-- ── deep link: the context opens straight onto every wing ─────────────────

for _, id in ipairs(WINGS) do
  onOpen(id)
  assert(findKey(rendered, "section-" .. id) ~= nil, id .. ": onOpen(context) opens the wing")
  assert(findKey(rendered, "rail-" .. id).props.fill == "primary", id .. ": the deep-linked wing is lit")
  stub.validate(rendered, "deep/" .. id)
end

-- A context that names no wing leaves the drawer on its current wing.
onOpen("no-such-wing")
assert(findKey(rendered, "section-media") ~= nil, "an unknown context keeps the open wing")

onClose()
assert(rendered ~= nil, "onClose leaves the last tree in place; the host closes the panel")

print(string.format("panel bodies: ok (%d wings, populated + unlit + deep link)", #WINGS))
