--!nonstrict
-- Mango bridge tests. Assembled by ../../../tests/run-museum-tests.sh.

-- ── socket discovery ─────────────────────────────────────────────────────

stub.rec.env.MANGO_INSTANCE_SIGNATURE = "/run/user/1000/mango-133583.sock"
stub.rec.dirs["/run/user/1000"] = { "mango-1.sock", "mango-2.sock", "wayland-0" }
stub.rec.files["/run/user/1000/mango-1.sock::info"] = { mtime = 10 }
stub.rec.files["/run/user/1000/mango-2.sock::info"] = { mtime = 20 }

assert(mango.socket() == "/run/user/1000/mango-133583.sock", "env signature wins")

stub.rec.env.MANGO_INSTANCE_SIGNATURE = nil
stub.rec.env.XDG_RUNTIME_DIR = "/run/user/1000"
assert(mango.socket() == "/run/user/1000/mango-2.sock", "socket scan picks the newest")

stub.rec.dirs["/run/user/1000"] = {}
assert(mango.socket() == nil, "no socket means no compositor bridge")
stub.rec.env.XDG_RUNTIME_DIR = nil
assert(mango.socket() == nil, "no runtime dir means no socket")

-- ── command construction ─────────────────────────────────────────────────

stub.rec.env.MANGO_INSTANCE_SIGNATURE = "/run/user/1000/mango-133583.sock"
local command = mango.streamCommand(mango.socket(), { "watch", "all-tags" })
assert(
  command == "MANGO_INSTANCE_SIGNATURE='/run/user/1000/mango-133583.sock' mmsg 'watch' 'all-tags'",
  "stream command is a quoted shell line: " .. command
)

local hostile = mango.streamCommand("/tmp/ma'ngo.sock", { "watch", "all-tags" })
assert(string.find(hostile, "'\\''", 1, true) ~= nil, "single quotes are escaped")
assert(string.find(hostile, "ma'ngo", 1, true) == nil, "raw quote never reaches the shell")

-- ── dispatch ─────────────────────────────────────────────────────────────

stub.rec.async = {}
mango.viewTag("DP-1", 2)
assert(#stub.rec.async == 1, "view is one dispatch, not two commands")
local viewArgv = stub.rec.async[1]
assert(viewArgv[1] == "env", "signature goes through env")
assert(viewArgv[2] == "MANGO_INSTANCE_SIGNATURE=/run/user/1000/mango-133583.sock", "signature argv")
assert(viewArgv[3] == "mmsg" and viewArgv[4] == "dispatch", "mmsg dispatch")
assert(viewArgv[5] == "viewcrossmon,2,DP-1", "viewcrossmon carries the bar's monitor")
assert(#viewArgv == 5, "no stray arguments")

stub.rec.async = {}
mango.viewTag(nil, 3)
assert(stub.rec.async[1][5] == "view,3", "without a monitor, view the focused one")

stub.rec.async = {}
mango.msg("panel-toggle", "control-center", "audio")
assert(#stub.rec.async == 1, "one IPC call")
assert(stub.rec.async[1][1] == "noctalia" and stub.rec.async[1][2] == "msg", "noctalia msg")
assert(stub.rec.async[1][5] == "audio", "context passed through")

-- ── tag selection ────────────────────────────────────────────────────────

local payload = {
  all_tags = {
    { monitor = "DP-3", tags = { { index = 1, is_active = true, client_count = 0 } } },
    {
      monitor = "DP-2",
      tags = { { index = 1, is_active = false, client_count = 0 }, { index = 2, is_active = true, client_count = 1 } },
    },
    {
      monitor = "DP-1",
      tags = {
        { index = 1, is_active = true, client_count = 3 },
        { index = 2, is_active = false, client_count = 1 },
        { index = 3, is_active = false, client_count = 0 },
      },
    },
  },
}

local shown, monitor = mango.hallTags(payload, "DP-1", 0, true)
assert(monitor == "DP-1", "the bar's monitor is chosen")
assert(#shown == 2, "only the populated halls show")
assert(shown[1].index == 1 and shown[2].index == 2, "order follows the compositor")

local all = mango.hallTags(payload, "DP-1", 0, false)
assert(#all == 3, "hide_when_empty = false shows all three")

local capped = mango.hallTags(payload, "DP-1", 1, false)
assert(#capped == 1 and capped[1].index == 1, "count caps the rail")

local fallback, fallbackMonitor = mango.hallTags(payload, "HDMI-A-1", 0, true)
assert(fallbackMonitor == "DP-3", "unknown monitor falls back to the first active one")
assert(#fallback == 1 and fallback[1].is_active, "fallback keeps the active hall")

local nothing, nothingMonitor = mango.hallTags(nil, "DP-1", 0, true)
assert(#nothing == 0 and nothingMonitor == "DP-1", "missing state is empty, not an error")

-- ── JSON decode (fixture shaped like `mmsg get all-tags`) ─────────────────

local line = [[{"all_tags":[{"monitor":"DP-1","tags":[{"index":1,"is_active":true,"is_urgent":false,"layout":"S","client_count":3},{"index":2,"is_active":false,"is_urgent":false,"layout":"S","client_count":1}]}]}]]
local decoded = stub.json.decode(line)
assert(decoded ~= nil, "mmsg line decodes")
assert(decoded.all_tags[1].monitor == "DP-1", "monitor decoded")
assert(decoded.all_tags[1].tags[1].is_active == true, "boolean decoded")
assert(decoded.all_tags[1].tags[1].client_count == 3, "number decoded")

-- ── one-shot query ───────────────────────────────────────────────────────

stub.rec.asyncResult = function(argv)
  assert(argv[3] == "mmsg" and argv[4] == "get" and argv[5] == "all-tags", "get argv")
  return { exitCode = 0, stdout = line }
end
local got = nil
mango.get({ "get", "all-tags" }, function(data)
  got = data
end)
assert(got ~= nil and got.all_tags[1].monitor == "DP-1", "get decodes the answer")

stub.rec.asyncResult = function()
  return { exitCode = 1, stdout = "" }
end
local failed = "unset"
mango.get({ "get", "all-tags" }, function(data)
  failed = data
end)
assert(failed == nil, "a failing mmsg answers nil, not a crash")

print("mango.luau: ok")
