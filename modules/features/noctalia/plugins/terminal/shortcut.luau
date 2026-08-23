--!nonstrict

function update()
  shortcut.setLabel("Terminal")
  shortcut.setIcon("terminal-2")
end

function onClick()
  noctalia.togglePanel("cernoh/terminal:panel")
end
