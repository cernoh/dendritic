--!nonstrict
-- Control-center shortcut: opens the Mirai panel.

function update()
  shortcut.setLabel(noctalia.tr("title"))
  shortcut.setIcon("cast")
end

function onClick()
  noctalia.togglePanel("cernoh/mirai:panel")
end
