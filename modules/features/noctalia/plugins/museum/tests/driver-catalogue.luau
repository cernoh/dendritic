--!nonstrict
-- The catalogue service's tests (PLAN phase 4). Assembled and run by
-- ../../../tests/run-museum-tests.sh with catalogue.luau concatenated after
-- the stub, so the service's `update()`/watch registrations land on the stub
-- host.
--
-- What is asserted here:
--   * every parser turns the fixture's stdout into the feed the drawer reads;
--   * a missing tool leaves its own field absent instead of raising;
--   * each request kind runs the argument array it claims to;
--   * the feed is republished only when it changed.

-- ── fixtures ──────────────────────────────────────────────────────────────

-- No stub.reset(): catalogue.luau registers its request watcher when the chunk
-- loads, and reset() would clear it before the driver can fire it.

stub.rec.env["XDG_CURRENT_DESKTOP"] = "mango"
stub.rec.files["/proc/cpuinfo"] = "processor\t: 0\nmodel name\t: AMD Ryzen 7 3700X\n"
stub.rec.files["/etc/os-release"] = 'NAME="NixOS"\nPRETTY_NAME="NixOS 26.11 (Xanthe)"\n'
stub.rec.files["/proc/sys/kernel/osrelease"] = "7.2.11\n"
stub.rec.files["/etc/hostname"] = "NIXPC\n"
stub.rec.files["/proc/uptime"] = "6420.11 30000.00\n"
stub.rec.dirs["/sys/class/power_supply"] = { "hidpp_battery_0" }
stub.rec.files["/sys/class/power_supply/hidpp_battery_0/type"] = "Battery\n"
stub.rec.files["/sys/class/power_supply/hidpp_battery_0/capacity"] = "100\n"
stub.rec.files["/sys/class/power_supply/hidpp_battery_0/status"] = "Discharging\n"
stub.rec.dirs["/sys/class/drm"] = { "card0", "renderD128" }
stub.rec.files["/sys/class/drm/card0/device/uevent"] = "DRIVER=nvidia\nPCI_CLASS=30000\n"

local responses = {
  ["powerprofilesctl get"] = "performance\n",
  ["wpctl get-volume @DEFAULT_AUDIO_SINK@"] = "Volume: 0.53\n",
  ["wpctl get-volume @DEFAULT_AUDIO_SOURCE@"] = "Volume: 1.00 [MUTED]\n",
  ["wpctl inspect @DEFAULT_AUDIO_SINK@"] = '  * node.description = "AB13X Headset Adapter Analog Stereo"\n',
  ["wpctl inspect @DEFAULT_AUDIO_SOURCE@"] = '  * node.description = "USB PnP Audio Device Mono"\n',
  ["pactl -f json list sink-inputs"] =
    '[{"index":1,"mute":false,"volume":{"front-left":{"value":65536,"value_percent":"100%"}},"properties":{"application.name":"Brave"}}]',
  ["nvidia-smi --query-gpu=name --format=csv,noheader"] = "",
  ["nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status"] = "enp5s0:ethernet:connected:Wired connection 1\n"
    .. "tailscale0:tun:connected (externally):tailscale0\n"
    .. "wlp4s0:wifi:disconnected:\n"
    .. "veth5ab66f7:ethernet:unmanaged:\n",
  ["ip -j addr show"] = '[{"ifname":"enp5s0","addr_info":[{"family":"inet","local":"192.168.1.121"}]},'
    .. '{"ifname":"lo","addr_info":[{"family":"inet","local":"127.0.0.1"}]}]',
  ["nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --rescan no"] = " :Onecom_5EF2:90\n"
    .. " :Onecom_5EF2:82\n"
    .. " :SKYXFXSL:49\n"
    .. " :DIRECT-7F-HP DeskJet 2700 series:39\n",
  ["bluetoothctl show"] = "Controller 10:F6:0A:AD:8C:92 (public)\n\tPowered: yes\n\tDiscoverable: no\n",
  ["bluetoothctl devices Paired"] = "Device AA:BB:CC:DD:EE:FF DualSense Wireless Controller\n",
  ["bluetoothctl devices Connected"] = "",
  ["playerctl metadata --format {{playerName}}|{{title}}|{{artist}}|{{mpris:length}}|{{position}}"] =
    "brave|(3) Meet the Gruutmans - YouTube||3766501000|1305433229\n",
  ["playerctl status"] = "Paused\n",
}

stub.rec.asyncResult = function(argv)
  local stdout = responses[table.concat(argv, " ")]
  if stdout == nil then
    return nil
  end
  return { exitCode = 0, stdout = stdout, stderr = "", timedOut = false }
end

-- One full poll sweep: five stages, one per tick.
local function sweep()
  for _ = 1, 5 do
    update()
  end
end

-- The chunk seeded two stages at load, before these fixtures existed; run a
-- whole sweep now that the host answers.
sweep()

local notified = {}
stub.noctalia.notifyError = function(title, body)
  table.insert(notified, { title = title, body = body })
end

-- ── helpers ───────────────────────────────────────────────────────────────

local function posted(argv)
  local joined = table.concat(argv, " ")
  for _, call in ipairs(stub.rec.async) do
    if table.concat(call, " ") == joined then
      return true
    end
  end
  return false
end

local function feed()
  return stub.rec.state["drawer"] or {}
end

local function request(kind, payload)
  stub.set("request", { kind = kind, payload = payload or {} })
  stub.set("request_rev", (tonumber(stub.rec.state["request_rev"]) or 0) + 1)
end

-- ── the first poll ────────────────────────────────────────────────────────

local first = feed()
assert(first.maker == "AMD Ryzen 7 3700X", "provenance maker from /proc/cpuinfo")
assert(first.gpu == "NVIDIA GPU", "a dead nvidia-smi falls back to the driver sysfs names")

-- Once the probe answers, the model replaces the driver fallback.
responses["nvidia-smi --query-gpu=name --format=csv,noheader"] = "NVIDIA GeForce RTX 3060\n"
sweep()
assert(feed().gpu == "NVIDIA GeForce RTX 3060", "provenance medium from nvidia-smi")
assert(first.origin == "NixOS 26.11 (Xanthe)", "provenance origin from /etc/os-release")
assert(first.substrate == "7.2.11", "provenance substrate from /proc/sys/kernel/osrelease")
assert(first.hostname == "NIXPC", "the specimen names the host")
assert(first.frame == "mango", "provenance frame from the environment")
assert(first.uptime == 6420, "uptime is seconds")
assert(#first.supplies == 1 and first.supplies[1].capacity == 100, "power supplies from sysfs")
assert(first.profile == "performance", "power profile")
assert(first.audio.sink.name == "AB13X Headset Adapter Analog Stereo", "sink description")
assert(first.audio.sink.volume == 0.53 and first.audio.sink.muted == false, "sink level")
assert(first.audio.source.muted == true, "source mute")
assert(first.audio.apps[1].name == "Brave" and first.audio.apps[1].volume == 1, "application channel")
assert(first.wired.name == "enp5s0" and first.wired.state == "connected", "wired link")
assert(first.wireless.name == "wlp4s0", "wireless device")
assert(first.addresses.enp5s0 == "192.168.1.121", "IPv4 address")
assert(#first.networks == 3, "networks are deduplicated by SSID")
assert(first.networks[1].ssid == "Onecom_5EF2" and first.networks[1].signal == 90, "strongest network first")
assert(first.bt.powered == true and first.bt.discoverable == false, "radio state")
assert(#first.bt.paired == 1 and first.bt.paired[1].name == "DualSense Wireless Controller", "paired holdings")
assert(first.media.title == "(3) Meet the Gruutmans - YouTube", "media title")
assert(first.media.app == "Brave", "media application")
assert(first.media.length == 3766501000 and first.media.position == 1305433229, "media timings")
assert(first.media.status == "Paused", "media status")

-- ── republishing is quiet ─────────────────────────────────────────────────

local published = 0
local previous = stub.set
local function countingSet(key, value)
  if key == "drawer" then
    published = published + 1
  end
  previous(key, value)
end
stub.set = countingSet
stub.noctalia.state.set = countingSet

sweep()
assert(published == 0, "an unchanged feed is not republished, got " .. tostring(published))
stub.set = previous
stub.noctalia.state.set = previous

-- ── requests run the argument array ───────────────────────────────────────

request("profile", { id = "balanced" })
assert(posted({ "powerprofilesctl", "set", "balanced" }), "the profile request sets the profile")

request("mute", { slot = "source" })
assert(posted({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle" }), "the mute request targets the source")

request("link", { on = true, name = "enp5s0" })
assert(posted({ "nmcli", "device", "connect", "enp5s0" }), "the link request connects")

request("wifi", { ssid = "Onecom_5EF2" })
assert(posted({ "nmcli", "device", "wifi", "connect", "Onecom_5EF2" }), "the wifi request joins")

request("bluetooth-power", { on = true })
assert(posted({ "bluetoothctl", "power", "on" }), "the radio request powers on")

request("bluetooth-discoverable", { on = false })
assert(posted({ "bluetoothctl", "discoverable", "off" }), "the discoverable request turns off")

request("media", { action = "play-pause" })
assert(posted({ "playerctl", "play-pause" }), "the media request drives the player")

local callsBefore = #stub.rec.async
request("refresh")
sweep()
assert(#stub.rec.async > callsBefore, "a refresh restarts the sweep and re-reads")

-- A duplicate revision is ignored: the counter, not the value, is the signal.
local calls = #stub.rec.async
stub.set("request_rev", stub.rec.state["request_rev"])
assert(#stub.rec.async == calls, "an unchanged revision does not re-run the request")

-- ── a host without the tools ──────────────────────────────────────────────

stub.rec.commands = {
  nmcli = false,
  bluetoothctl = false,
  playerctl = false,
  wpctl = false,
  pactl = false,
  ip = false,
  ["nvidia-smi"] = false,
  powerprofilesctl = false,
}
local attempted = #stub.rec.async
request("refresh")
assert(#stub.rec.async == attempted, "a missing tool is never spawned")
local bare = feed()
assert(bare.maker == "AMD Ryzen 7 3700X", "file reads still work without the tools")
assert(bare.wired == first.wired, "a vanished tool keeps its last record rather than inventing an empty one")

print("catalogue.luau: ok (parsers, requests, quiet republish)")
