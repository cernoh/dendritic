--!nonstrict
-- halls — roman-numeral hall plates, active brass, tracks super+2.
-- Data: telemetry "tags" (mmsg watch all-tags). Click: mmsg viewcrossmon,
-- so the bar's monitor switches, not whichever monitor has focus.

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local hideEmpty = noctalia.getConfig("hide_when_empty")
if hideEmpty == nil then
  hideEmpty = true
end
local count = noctalia.getConfig("count") or 0

local function select(index)
  mango.viewTag(barWidget.outputName(), index)
end

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  local tags = mango.hallTags(noctalia.state.get("tags"), barWidget.outputName(), count, hideEmpty)
  local tree = bar.halls({ tags = tags, onSelect = select })
  if tree == nil then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(tree)
end

noctalia.state.watch("tags", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

render()
