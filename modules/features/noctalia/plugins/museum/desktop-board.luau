--!nonstrict
-- The mounted instrument board (PLAN 5.1).
--
-- One walnut board carries the four `sysmon` tiles' readings at the same
-- footprint (44,122 → 544,428): gpu load · vram · cpu load · ram. The data is
-- the telemetry service's `stats` key — one runtime owns the system-monitor
-- sample, so three desktop tiles do not each poll it. Needle dials are Tier B,
-- so each instrument is a Meter plus its numeral (PLAN 5.1).

local desktop = require("./lib/desktop.luau")

local function render()
  desktopWidget.render(desktop.board({
    stats = noctalia.state.get("stats"),
  }))
end

noctalia.state.watch("stats", render)
noctalia.setUpdateInterval(2000)

function update()
  render()
end

render()
