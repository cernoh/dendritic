--!nonstrict
-- clock — the centred brass clock placard: time and date, two lines.
-- The built-in [widget.clock] can change its format but not its material, so
-- the museum replaces it (PLAN 3.4 decision).

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local timeFormat = noctalia.getConfig("time_format") or "%H:%M"
local dateFormat = noctalia.getConfig("date_format") or "%a %d %b"

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(bar.clock({
    time = noctalia.formatTime(timeFormat),
    date = noctalia.formatTime(dateFormat),
  }))
end

noctalia.setUpdateInterval(1000)

function update()
  render()
end

function onClick()
  mango.msg("panel-toggle", "control-center", "calendar")
end

render()
