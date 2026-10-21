--!nonstrict
-- Control-centre shortcut: opens the catalogue drawer.
--
-- The drawer is reachable from the bar and from a keybind; this tile is the
-- third way in, from the control centre's Home tab, so the museum surface is
-- where the shell's own shortcuts are.

function update()
  shortcut.setLabel(noctalia.tr("shortcut.label"))
  shortcut.setIcon("building-bank")
end

function onClick()
  noctalia.togglePanel("cernoh/museum:panel")
end
