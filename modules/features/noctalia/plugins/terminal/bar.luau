--!nonstrict

function update()
  barWidget.setGlyph("terminal-2")
  barWidget.setText("Terminal")
end

function onClick()
  noctalia.togglePanel("cernoh/terminal:panel")
end

function onRightClick()
  noctalia.openSettings()
end
