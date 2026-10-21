--!nonstrict
-- label — the NOW VIEWING wall label carrying the focused window title.
-- Data: telemetry "active" (mmsg watch focusing-client, which re-emits on a
-- title change). Long titles are truncated at max_length, the built-in
-- [widget.active_window] default (260).

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local maxLength = noctalia.getConfig("max_length") or 260
local caption = noctalia.getConfig("caption") or ""

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  local active = noctalia.state.get("active")
  barWidget.setVisible(true)
  barWidget.render(bar.label({
    title = active ~= nil and active.title or "",
    maxLength = maxLength,
    caption = caption ~= "" and caption or nil,
  }))
end

noctalia.state.watch("active", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

function onRightClick()
  mango.msg("panel-toggle", "control-center")
end

render()
