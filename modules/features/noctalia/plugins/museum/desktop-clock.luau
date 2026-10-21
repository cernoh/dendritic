--!nonstrict
-- The clock placard (PLAN 5.2), 464×96 at 64,452.
--
-- The built-in desktop clock can be brass, serif and boxed, but its digital
-- form is a single label: no second line for the date and no level meter. The
-- artifact's placard is the acceptance target, so this is a plugin tile; the
-- meter counts the minute's seconds.

local desktop = require("./lib/desktop.luau")

local timeFormat = "%H:%M"
-- Luau's os.date does not implement %e (space-padded day); %d with the leading
-- zero stripped matches the artifact's "Wednesday 21 October".
local dateFormat = "%A %d %B"

local function render()
  local now = os.time()
  local date = string.gsub(os.date(dateFormat, now), " 0(%d)", " %1")
  desktopWidget.render(desktop.clock({
    time = os.date(timeFormat, now),
    date = date,
    second = tonumber(os.date("%S", now)),
  }))
end

desktopWidget.setWantsSecondTicks(true)

function update()
  render()
end

render()
