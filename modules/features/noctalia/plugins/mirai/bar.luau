--!nonstrict
-- Bar widget: a cast glyph, the current Mirai state, and the panel on click.

local LABELS = {
  source = "bar.casting",
  sink = "bar.receiving",
}

local function label()
  local snapshot = noctalia.state.get("snapshot")
  if snapshot ~= nil and snapshot.installed == true and snapshot.running == true then
    return noctalia.tr(LABELS[snapshot.mode] or "bar.idle")
  end
  return noctalia.tr("bar.idle")
end

function update()
  barWidget.setGlyph("cast")
  barWidget.setText(label())
end

function onClick()
  noctalia.togglePanel("cernoh/mirai:panel")
end

function onRightClick()
  noctalia.openSettings()
end
