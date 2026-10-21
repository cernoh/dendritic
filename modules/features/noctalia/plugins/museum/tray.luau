--!nonstrict
-- tray — exhibit plate · tray plate · wax seal · audio plate · brass power.
-- The four built-ins it replaces (media, tray, notifications, volume +
-- brightness, session) have no plugin API at plugin_api 34, so the telemetry
-- service publishes live values from the same sources the shell uses.
-- Needle-free by design: the seal is a disc, the plates are engraved fields.

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local showMedia = noctalia.getConfig("show_media")
if showMedia == nil then
  showMedia = true
end
local showAudio = noctalia.getConfig("show_audio")
if showAudio == nil then
  showAudio = true
end
local showUnread = noctalia.getConfig("show_unread")
if showUnread == nil then
  showUnread = true
end

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(bar.tray({
    media = showMedia and noctalia.state.get("media") or nil,
    audio = noctalia.state.get("audio"),
    unread = noctalia.state.get("unread") or 0,
    showAudio = showAudio,
    showUnread = showUnread,
  }))
end

noctalia.state.watch("media", render)
noctalia.state.watch("audio", render)
noctalia.state.watch("unread", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

function onRightClick()
  mango.msg("panel-toggle", "control-center")
end

render()
