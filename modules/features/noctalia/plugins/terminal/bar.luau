--!nonstrict
-- Bar widget: the terminal glyph, tinted by the shell's state, and the panel on
-- click. The panel is the terminal window, so the bar is where the state of
-- that shell stays visible while it is closed.

local function label()
  local status = noctalia.state.get("status")
  if status == "ready" then
    return noctalia.tr("status.ready")
  elseif status == "exited" then
    return noctalia.tr("status.exited")
  elseif status == "unavailable" then
    return noctalia.tr("status.unavailable")
  end
  return noctalia.tr("status.starting")
end

function update()
  local ready = noctalia.state.get("status") == "ready"
  barWidget.setGlyph("terminal-2")
  barWidget.setText(ready and noctalia.tr("bar.label") or label())
  barWidget.setGlyphColor(ready and "primary" or "error")
  barWidget.setTooltip(label())
end

function onClick()
  noctalia.togglePanel("cernoh/terminal:panel")
end

function onRightClick()
  noctalia.openSettings()
end
