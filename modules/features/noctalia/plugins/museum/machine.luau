--!nonstrict
-- machine — Plate + Ledger: ram · cpu · gpu.
-- Data: telemetry "stats" (noctalia.systemStats, the shell's monitor).
-- PLAN 3.3: sourced from the host, never by shelling out.

local bar = require("./lib/bar.luau")
local mango = require("./lib/mango.luau")

local showGpu = noctalia.getConfig("show_gpu")
if showGpu == nil then
  showGpu = true
end

local function render()
  if not bar.horizontal() then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  barWidget.render(bar.machine({
    stats = noctalia.state.get("stats"),
    showGpu = showGpu,
  }))
end

noctalia.state.watch("stats", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

function onRightClick()
  mango.msg("panel-toggle", "control-center", "system")
end

render()
