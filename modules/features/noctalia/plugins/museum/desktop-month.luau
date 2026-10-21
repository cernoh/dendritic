--!nonstrict
-- The month plate (PLAN 5.3), 620×420 at 40,573.
--
-- The same component as the catalogue drawer's VIII, rendered at desktop
-- scale. The two chevrons move the display month; the plate always opens on
-- the current one. The wall text names the shell's calendar state rather than
-- promising events the plugin cannot read.

local desktop = require("./lib/desktop.luau")

local offset = 0

local function render()
  desktopWidget.render(desktop.month({
    offset = offset,
    onPrev = function()
      offset = offset - 1
      render()
    end,
    onNext = function()
      offset = offset + 1
      render()
    end,
  }))
end

noctalia.setUpdateInterval(60000)

function update()
  render()
end

render()
