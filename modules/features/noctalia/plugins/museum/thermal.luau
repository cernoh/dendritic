--!nonstrict
-- thermal — Plate + Ledger: cpu temp · drive temp, plus the segmented
-- drive-degradation gauge (PLAN 3.5).
-- Data: telemetry "stats" (cpu temp) and "drives" (the drive-health collector
-- at /run/noctalia-drive-health/raw.json, read not re-collected).

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local showGauge = noctalia.getConfig("show_gauge")
if showGauge == nil then
  showGauge = true
end

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(bar.thermal({
    stats = noctalia.state.get("stats"),
    drives = noctalia.state.get("drives"),
    showGauge = showGauge,
  }))
end

noctalia.state.watch("stats", render)
noctalia.state.watch("drives", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

function onRightClick()
  mango.msg("panel-toggle", "control-center", "system")
end

render()
