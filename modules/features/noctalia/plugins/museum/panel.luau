--!nonstrict
-- The catalogue drawer: a museum surface with a Wing Index rail and ten
-- sections, one per wing of `artifacts/museum-control-panels.html`.
--
-- This is a parallel surface, not a restyle of the control centre: the ten
-- control-centre tabs render in C++ and cannot be restyled from a plugin. The
-- drawer rebuilds them from the museum components — `lib/museum.luau` for the
-- materials and primitives, `lib/drawer.luau` for drawer-scale plate, ledger,
-- slip, lever, meter and tab geometry — in the vocabulary DESIGN.md §6.3 maps,
-- one section per tab:
--
--   I    System     Condition report — instruments, provenance, inventory
--   II   Power      Three-position profile throw, connected devices
--   III  Audio      Channel strips: name · meter · value · mute throw
--   IV   Display    One plate per lamp, format and designation on ruled lines
--   V    Network    Wired plate + link throw, wireless registry with signal
--   VI   Bluetooth  Radio plate with two throws, paired holdings
--   VII  Weather    Almanac: UNLOCATED slip, readings, ephemeris
--   VIII Calendar   Month plate with today as a brass seal, wall-text slip
--   IX   Notices    Accession drawer: one slip per notice, date index tabs
--   X    Media      Now exhibiting: wall label, position, brass transport
--
-- The panel reads; the service fetches (module AGENTS.md). Every record on
-- this surface arrives one of two ways:
--
--   * `catalogue.luau` publishes the drawer's feed on the `drawer` state key —
--     provenance, power profile, audio channels, network registry, Bluetooth
--     holdings, media — and owns every CLI read behind them (`page 49`). It
--     also executes the drawer's requests (`profile`, `mute`, `link`, `wifi`,
--     `bluetooth-*`, `media`, `refresh`), so no subprocess starts here.
--   * the plugin API is called directly, because it is synchronous and has no
--     command behind it: `noctalia.systemStats` (cpu/ram/gpu/net/load),
--     `diskMounts`/`diskStats` (inventory), `noctalia.outputs()` (lamps),
--     `getSetting` (`[location]`, `[calendar]`), and the notification
--     `unread` count.
--
-- Two further state keys are read when the plugin's service publishes them:
-- `notifications` (a list of `{ title, app, body, age_days, stamp }`) and
-- `bands` (32 numbers, 0..1, for the oscillograph). Without them the Notices
-- drawer stamps its register EMPTY and the oscillograph draws a flat baseline
-- labelled NO SIGNAL — and the unread count is named rather than hidden.
--
-- tests/driver-panel.luau asserts every section against a feed fixture.

local museum = require("./lib/museum.luau")
local drawer = require("./lib/drawer.luau")

local T = museum.t

-- The rail glyphs are the shell's own proven tab glyphs (AGENTS.md 0.6), not
-- names that merely resolve: these ten are the ones the live rail draws.
local SECTIONS = {
  { id = "system", numeral = "I", glyph = "activity-heartbeat", name = "wing.system", title = "title.system" },
  { id = "power", numeral = "II", glyph = "battery-charging-2", name = "wing.power", title = "title.power" },
  { id = "audio", numeral = "III", glyph = "volume", name = "wing.audio", title = "title.audio" },
  { id = "display", numeral = "IV", glyph = "device-desktop", name = "wing.display", title = "title.display" },
  { id = "network", numeral = "V", glyph = "wifi", name = "wing.network", title = "title.network" },
  { id = "bluetooth", numeral = "VI", glyph = "bluetooth", name = "wing.bluetooth", title = "title.bluetooth" },
  { id = "weather", numeral = "VII", glyph = "weather-cloud-sun", name = "wing.weather", title = "title.weather" },
  { id = "calendar", numeral = "VIII", glyph = "calendar-event", name = "wing.calendar", title = "title.calendar" },
  { id = "notices", numeral = "IX", glyph = "bell", name = "wing.notices", title = "title.notices" },
  { id = "media", numeral = "X", glyph = "disc", name = "wing.media", title = "title.media" },
}

-- The profile names `powerprofilesctl` accepts, in the order the throw shows
-- them (DESIGN.md: power saver · balanced · performance).
local PROFILES = {
  { id = "power-saver", label = "Power saver" },
  { id = "balanced", label = "Balanced" },
  { id = "performance", label = "Performance" },
}

local NOTICE_TABS = { "All", "Today", "Yesterday", "Older" }

local open = false
local active = 1
local monthOffset = 0
local noticeFilter = 1

-- The service's drawer feed. A key that is absent means "not read yet"; a
-- section must be able to tell that from "read, and empty", and say which.
local feed = {}

local render

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function tr(key)
  return noctalia.tr(key)
end

local function dash(value)
  if value == nil or value == "" then
    return "—"
  end
  return tostring(value)
end

local function upper(text)
  return string.upper(tostring(text))
end

-- Bytes per second as a short brass numeral: 4.2k, 128, 2.1M.
local function rate(bytes)
  if bytes == nil then
    return "—"
  end
  if bytes >= 1e9 then
    return string.format("%.1fG", bytes / 1e9)
  end
  if bytes >= 1e6 then
    return string.format("%.1fM", bytes / 1e6)
  end
  if bytes >= 1e3 then
    return string.format("%.1fk", bytes / 1e3)
  end
  return string.format("%.0f", bytes)
end

local function trim(text)
  if text == nil then
    return nil
  end
  return (string.gsub(tostring(text), "^%s*(.-)%s*$", "%1"))
end

-- Work is posted, never run here. A request is a plain value plus a revision
-- counter: two identical requests in a row must both run, and a bare value
-- comparison would swallow the second (the terminal plugin shares this channel
-- for the same reason).
local function request(kind, payload)
  noctalia.state.set("request", { kind = kind, payload = payload })
  noctalia.state.set("request_rev", (tonumber(noctalia.state.get("request_rev")) or 0) + 1)
end

local function notices()
  local list = noctalia.state.get("notifications")
  if type(list) ~= "table" then
    return {}
  end
  return list
end

local function bands()
  local list = noctalia.state.get("bands")
  if type(list) ~= "table" then
    return nil
  end
  return list
end

local function statsOrEmpty()
  return noctalia.systemStats() or {}
end

local function mountLabel(path)
  if path == "/" then
    return "Root"
  end
  return string.match(path, "([^/]+)$") or path
end

local function uptimeText(seconds)
  if seconds == nil then
    return "—"
  end
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if days > 0 then
    return string.format("%dd %dh", days, hours)
  end
  return string.format("%dh %02dm", hours, minutes)
end

local function clockText(microseconds)
  local seconds = tonumber(microseconds)
  if seconds == nil or seconds <= 0 then
    return "—"
  end
  seconds = math.floor(seconds / 1e6)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local remainder = seconds % 60
  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, remainder)
  end
  return string.format("%d:%02d", minutes, remainder)
end

-- ---------------------------------------------------------------------------
-- I — System: the condition report
-- ---------------------------------------------------------------------------

local function systemBody()
  local stats = statsOrEmpty()
  local cpu = stats.cpu or {}
  local ram = stats.ram or {}
  local gpu = stats.gpu or {}
  local net = stats.net or {}

  local vram = gpu.vramUsedBytes
  local gpuNote = museum.temp(gpu.tempC)
  if vram ~= nil then
    gpuNote = gpuNote .. " · " .. string.format("%.1f GiB", vram / 1073741824)
  end

  local instruments = drawer.plate({
    key = "system-instruments",
    caption = tr("caption.instruments"),
    note = tr("note.live"),
  }, {
    ui.row({ gap = 14, align = "stretch" }, {
      drawer.readout({
        key = "instrument-cpu",
        label = "cpu",
        value = museum.pct(cpu.usagePercent),
        meter = (cpu.usagePercent or 0) / 100,
        note = cpu.tempC ~= nil and museum.temp(cpu.tempC) or tr("note.probe"),
        flexGrow = 1,
      }),
      drawer.readout({
        key = "instrument-ram",
        label = "memory",
        value = museum.pct(ram.usagePercent),
        meter = (ram.usagePercent or 0) / 100,
        note = museum.megabytes(ram.usedMb),
        flexGrow = 1,
      }),
      drawer.readout({
        key = "instrument-gpu",
        label = "gpu",
        value = museum.pct(gpu.usagePercent),
        meter = (gpu.usagePercent or 0) / 100,
        note = gpuNote,
        flexGrow = 1,
      }),
      drawer.readout({
        key = "instrument-net",
        label = "net in",
        value = rate(net.rxBytesPerSec),
        meter = math.min(1, (net.rxBytesPerSec or 0) / 5e6),
        note = rate(net.txBytesPerSec) .. " " .. tr("note.out"),
        flexGrow = 1,
      }),
    }),
  })

  local provenance = drawer.plate({
    key = "system-provenance",
    caption = tr("caption.provenance"),
    flexGrow = 1,
  }, {
    drawer.ledger({
      key = "system-provenance-ledger",
      cells = {
        { key = tr("row.maker"), value = dash(feed.maker) },
        { key = tr("row.medium"), value = dash(feed.gpu) },
        { key = tr("row.origin"), value = dash(feed.origin) },
        { key = tr("row.substrate"), value = dash(feed.substrate) },
        { key = tr("row.frame"), value = dash(feed.frame) },
        { key = tr("row.onloan"), value = uptimeText(feed.uptime) },
      },
      keyWidth = 120,
    }),
  })

  local mounts = {}
  for index, mount in ipairs(noctalia.diskMounts() or {}) do
    if index > 8 then
      break
    end
    local disk = noctalia.diskStats(mount.path)
    if disk ~= nil then
      mounts[#mounts + 1] = {
        key = mountLabel(mount.path),
        rawKey = true,
        value = string.format(
          "%.1f / %.1f GB",
          ((disk.totalBytes or 0) - (disk.freeBytes or 0)) / 1e9,
          (disk.totalBytes or 0) / 1e9
        ),
        gauge = (disk.usagePercent or 0) / 100,
      }
    end
  end

  local load = stats.loadAvg or {}
  local inventory = drawer.plate({
    key = "system-inventory",
    caption = tr("caption.inventory"),
    note = tostring(#mounts) .. " " .. tr("note.volumes"),
    flexGrow = 1,
  }, {
    drawer.ledger({ key = "system-inventory-ledger", cells = mounts, keyWidth = 110 }),
    drawer.ledger({
      key = "system-inventory-foot",
      cells = {
        {
          key = tr("row.loadavg"),
          value = load[1] == nil and "—"
            or string.format("%.2f / %.2f / %.2f", load[1], load[2] or 0, load[3] or 0),
        },
        { key = tr("row.swap"), value = museum.megabytes((stats.swap or {}).usedMb) },
      },
      keyWidth = 110,
    }),
  })

  return {
    ui.column({ key = "section-system", gap = 12, flexGrow = 1 }, {
      instruments,
      ui.row({ key = "system-ledgers", gap = 12, align = "stretch" }, {
        provenance,
        inventory,
      }),
    }),
  }
end

-- ---------------------------------------------------------------------------
-- II — Power: the gallery lighting
-- ---------------------------------------------------------------------------

local function powerBody()
  local index = 1
  for position, profile in ipairs(PROFILES) do
    if profile.id == feed.profile then
      index = position
    end
  end

  local labels = {}
  for _, profile in ipairs(PROFILES) do
    labels[#labels + 1] = profile.label
  end

  local profilePlate = drawer.plate({
    key = "power-profile",
    caption = tr("caption.profile"),
    note = tr("note.threeposition"),
  }, {
    drawer.lever({
      labels = labels,
      index = index,
      onSelect = function(position)
        local profile = PROFILES[position]
        if profile == nil then
          return
        end
        feed.profile = profile.id
        render()
        request("profile", { id = profile.id })
      end,
    }),
    drawer.ledger({
      key = "power-profile-ledger",
      cells = { { key = tr("row.active"), value = dash(feed.profile) } },
      keyWidth = 90,
    }),
  })

  local rows = {}
  for _, supply in ipairs(feed.supplies or {}) do
    local capacity = supply.capacity
    rows[#rows + 1] = {
      key = supply.name,
      rawKey = true,
      value = capacity ~= nil and (tostring(capacity) .. "%") or string.lower(supply.status or "—"),
      gauge = capacity and (capacity / 100) or nil,
    }
  end
  if #rows == 0 then
    rows[1] = { key = tr("row.device"), value = "—" }
  end

  local devices = drawer.plate({
    key = "power-devices",
    caption = tr("caption.devices"),
    note = tostring(#rows),
  }, {
    drawer.ledger({ key = "power-devices-ledger", cells = rows, keyWidth = 150 }),
    ui.label({
      text = tr("note.chargeunreported"),
      fontSize = 10,
      fontFamily = "monospace",
      color = drawer.alpha(T.paperDim, 0.9),
      maxLines = 2,
    }),
  })

  return {
    ui.column({ key = "section-power", gap = 12 }, { profilePlate, devices }),
  }
end

-- ---------------------------------------------------------------------------
-- III — Audio: channel strips
-- ---------------------------------------------------------------------------

-- A channel strip row: name · meter · value · mute throw. The meter is the
-- segmented gauge, because a panel cannot place a fader knob.
local function channelRow(spec)
  return ui.row({
    key = spec.key,
    gap = 10,
    align = "center",
    paddingV = 6,
  }, {
    ui.label({
      text = spec.name,
      fontSize = 11,
      fontFamily = "monospace",
      color = T.bone,
      flexGrow = 1,
      maxLines = 1,
    }),
    drawer.meter({
      value = spec.value,
      segments = 12,
      width = 140,
      height = 6,
      fill = spec.muted and drawer.alpha(T.brassDk, 0.5) or nil,
    }),
    ui.label({
      text = museum.pct((spec.value or 0) * 100),
      fontSize = 11,
      fontFamily = "monospace",
      color = T.brassLt,
      width = 42,
      textAlign = "right",
    }),
    drawer.toggle({ on = spec.muted, onSelect = spec.onSelect }),
  })
end

local function audioBody()
  local audio = feed.audio or {}
  local function stripPlate(slot, channel, caption, note)
    return drawer.plate({
      key = "audio-" .. slot,
      caption = caption,
      note = note,
      flexGrow = 1,
    }, {
      ui.label({
        text = dash(channel.name),
        fontSize = 12,
        fontFamily = "monospace",
        color = T.bone,
        maxLines = 1,
      }),
      channelRow({
        key = "audio-" .. slot .. "-strip",
        name = upper(tr("row.level")),
        value = channel.volume,
        muted = channel.muted,
        onSelect = function()
          channel.muted = not channel.muted
          render()
          request("mute", { slot = slot })
        end,
      }),
    })
  end

  local appRows = {}
  for index, app in ipairs(audio.apps or {}) do
    appRows[#appRows + 1] = channelRow({
      key = "audio-app-" .. tostring(index),
      name = app.name,
      value = app.volume,
      muted = app.muted,
      onSelect = function()
        app.muted = not app.muted
        render()
      end,
    })
  end
  if #appRows == 0 then
    appRows[1] = ui.label({
      text = tr("empty.channels"),
      fontSize = 11,
      fontFamily = "monospace",
      color = T.paperDim,
      maxLines = 2,
    })
  end

  return {
    ui.column({ key = "section-audio", gap = 12 }, {
      ui.row({ gap = 12, align = "stretch" }, {
        stripPlate("sink", audio.sink or {}, tr("caption.output"), tr("note.analogstereo")),
        stripPlate("source", audio.source or {}, tr("caption.input"), tr("note.devicemono")),
      }),
      drawer.plate({
        key = "audio-apps",
        caption = tr("caption.apps"),
        note = tostring(#(audio.apps or {})),
      }, appRows),
    }),
  }
end

-- ---------------------------------------------------------------------------
-- IV — Display: one plate per lamp
-- ---------------------------------------------------------------------------

local function displayBody()
  local outputs = noctalia.outputs() or {}
  local plates = {}
  for _, lamp in ipairs(outputs) do
    local lit = (lamp.width or 0) > 0
    local opacity
    if not lit then
      opacity = 0.55
    end
    table.insert(plates, drawer.plate({
      key = "display-" .. tostring(lamp.name),
      caption = dash(lamp.description),
      note = tostring(lamp.name) .. " · " .. (lit and tr("note.lit") or tr("note.dark")),
      opacity = opacity or 1,
    }, {
      drawer.ledger({
        key = "display-ledger-" .. tostring(lamp.name),
        keyWidth = 120,
        cells = {
          { key = tr("row.designation"), value = dash(lamp.name) },
          {
            key = tr("row.format"),
            value = tostring(lamp.width or "—") .. " × " .. tostring(lamp.height or "—"),
          },
          { key = tr("row.scale"), value = dash(lamp.scale) },
          { key = tr("row.position"), value = tostring(lamp.x or "—") .. ", " .. tostring(lamp.y or "—") },
        },
      }),
      ui.row({ gap = 10, align = "center" }, {
        ui.label({
          text = upper(tr("row.lamp")),
          fontSize = 9,
          fontWeight = "bold",
          fontFamily = "monospace",
          color = T.paperDim,
          flexGrow = 1,
        }),
        drawer.meter({ value = lit and 1 or 0, segments = 1, width = 22, height = 8 }),
        ui.label({
          text = lit and upper(tr("state.on")) or upper(tr("state.off")),
          fontSize = 9,
          fontFamily = "monospace",
          color = lit and T.brassLt or T.paperDim,
          width = 34,
          textAlign = "right",
        }),
      }),
    }))
  end
  if #plates == 0 then
    table.insert(plates, drawer.slip({
      key = "display-empty",
      stamp = tr("stamp.dark"),
      title = tr("empty.lamps"),
      line = tr("empty.lamps.body"),
      footerLeft = tr("row.gallery"),
      footerRight = tr("note.noreport"),
    }))
  end
  return {
    ui.column({ key = "section-display", gap = 11 }, plates),
  }
end

-- ---------------------------------------------------------------------------
-- V — Network: the registry
-- ---------------------------------------------------------------------------

local function networkBody()
  local wired = feed.wired or {}
  local wireless = feed.wireless or {}
  local addresses = feed.addresses or {}

  local wiredPlate = drawer.plate({
    key = "network-wired",
    caption = tr("caption.wired"),
    note = wired.state == "connected" and tr("note.engaged") or tr("note.idle"),
    flexGrow = 1,
  }, {
    drawer.ledger({
      key = "network-wired-ledger",
      keyWidth = 90,
      cells = {
        { key = tr("row.interface"), value = dash(wired.name) },
        { key = tr("row.address"), value = dash(addresses[wired.name]) },
      },
    }),
    ui.row({ gap = 10, align = "center" }, {
      ui.label({
        text = upper(tr("row.link")),
        fontSize = 9,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = T.paperDim,
        flexGrow = 1,
      }),
      drawer.toggle({
        on = wired.state == "connected",
        onSelect = function(on)
          if wired.name == nil then
            return
          end
          request("link", { on = on, name = wired.name })
        end,
      }),
    }),
  })

  local wifiRows = {}
  for index, network in ipairs(feed.networks or {}) do
    if index > 7 then
      break
    end
    wifiRows[#wifiRows + 1] = {
      key = network.ssid,
      rawKey = true,
      value = tostring(network.signal) .. "%",
      gauge = network.signal / 100,
      segments = 4,
      gaugeWidth = 34,
      nodeKey = "network-wifi-" .. tostring(index),
      tooltip = tr("note.connect"),
      onClick = function()
        request("wifi", { ssid = network.ssid })
      end,
    }
  end
  if #wifiRows == 0 then
    wifiRows[1] = { key = tr("row.registry"), value = "—" }
  end

  local wirelessPlate = drawer.plate({
    key = "network-wireless",
    caption = tr("caption.wireless"),
    note = tostring(#(feed.networks or {})) .. " " .. tr("note.found"),
    flexGrow = 1,
  }, {
    drawer.ledger({ key = "network-wireless-ledger", cells = wifiRows, keyWidth = 140, segments = 4 }),
    ui.label({
      text = wireless.name ~= nil and (upper(wireless.name) .. " · " .. upper(wireless.state or "")) or "",
      fontSize = 9,
      fontFamily = "monospace",
      color = drawer.alpha(T.paperDim, 0.9),
      maxLines = 1,
    }),
  })

  local notes = drawer.plate({
    key = "network-notes",
    caption = tr("caption.notes"),
    note = tr("note.accession"),
  }, {
    drawer.ledger({
      key = "network-notes-ledger",
      keyWidth = 140,
      cells = {
        { key = tr("row.wiredlink"), value = dash(wired.state) },
        { key = tr("row.wirelessradio"), value = dash(wireless.state) },
        { key = tr("row.registry"), value = tostring(#(feed.networks or {})) .. " " .. tr("note.wifi") },
      },
    }),
  })

  return {
    ui.column({ key = "section-network", gap = 12 }, {
      ui.row({ gap = 12, align = "stretch" }, { wiredPlate, wirelessPlate }),
      notes,
    }),
  }
end

-- ---------------------------------------------------------------------------
-- VI — Bluetooth: the wireless registry
-- ---------------------------------------------------------------------------

local function bluetoothRow(id, label, on, onSelect)
  return ui.row({ key = "bluetooth-" .. id .. "-row", gap = 11, align = "center", paddingV = 4 }, {
    ui.label({
      text = upper(label),
      fontSize = 9,
      fontWeight = "bold",
      fontFamily = "monospace",
      color = T.paperDim,
      flexGrow = 1,
    }),
    drawer.toggle({ on = on, onSelect = onSelect }),
    ui.label({
      text = on and upper(tr("state.on")) or upper(tr("state.off")),
      fontSize = 9,
      fontFamily = "monospace",
      color = on and T.brassLt or T.paperDim,
      width = 34,
      textAlign = "right",
    }),
  })
end

local function bluetoothBody()
  local bt = feed.bt or {}
  local powered = bt.powered == true
  local discoverable = bt.discoverable == true

  local radio = drawer.plate({
    key = "bluetooth-radio",
    caption = tr("caption.radio"),
    note = powered and tr("note.engaged") or tr("note.idle"),
  }, {
    bluetoothRow("radio", tr("row.bluetooth"), powered, function(on)
      bt.powered = on
      render()
      request("bluetooth-power", { on = on })
    end),
    bluetoothRow("discoverable", tr("row.discoverable"), discoverable, function(on)
      bt.discoverable = on
      render()
      request("bluetooth-discoverable", { on = on })
    end),
  })

  local connected = bt.connected or {}
  local paired = bt.paired or {}
  local rows = {}
  for _, device in ipairs(connected) do
    rows[#rows + 1] = { key = device.name, rawKey = true, value = tr("note.connected") }
  end
  for _, device in ipairs(paired) do
    local listed = false
    for _, live in ipairs(connected) do
      if live.address == device.address then
        listed = true
      end
    end
    if not listed then
      rows[#rows + 1] = { key = device.name, rawKey = true, value = tr("note.paired") }
    end
  end

  local holdings
  if #rows == 0 then
    holdings = drawer.slip({
      key = "bluetooth-empty",
      stamp = tr("stamp.empty"),
      title = tr("empty.holdings"),
      line = tr("empty.holdings.body"),
      footerLeft = tr("row.registry"),
      footerRight = tostring(#paired) .. " " .. tr("note.paired"),
    })
  else
    holdings = drawer.plate({
      key = "bluetooth-holdings",
      caption = tr("caption.holdings"),
      note = tostring(#rows),
    }, {
      drawer.ledger({ key = "bluetooth-holdings-ledger", cells = rows, keyWidth = 260 }),
    })
  end

  return {
    ui.column({ key = "section-bluetooth", gap = 12 }, { radio, holdings }),
  }
end

-- ---------------------------------------------------------------------------
-- VII — Weather: the almanac
-- ---------------------------------------------------------------------------

local function weatherBody()
  local address = trim(noctalia.getSetting("location.address"))
  local autoLocate = noctalia.getSetting("location.auto_locate") == true
  local located = (address ~= nil and address ~= "") or autoLocate

  local slip
  if located then
    slip = drawer.slip({
      key = "weather-station",
      stamp = tr("stamp.station"),
      tone = "green",
      title = (address ~= nil and address ~= "") and address or tr("note.autolocate"),
      line = tr("weather.station.body"),
      footerLeft = tr("note.observation"),
      footerRight = tr("note.pending"),
    })
  else
    slip = drawer.slip({
      key = "weather-unlocated",
      stamp = tr("stamp.unlocated"),
      title = tr("empty.station"),
      line = tr("empty.station.body"),
      footerLeft = tr("note.observation"),
      footerRight = "—",
    })
  end

  local readings = drawer.plate({
    key = "weather-readings",
    caption = tr("caption.readings"),
    note = located and tr("note.pending") or tr("note.awaiting"),
  }, {
    drawer.ledger({
      key = "weather-readings-ledger",
      keyWidth = 120,
      cells = {
        { key = tr("row.feelslike"), value = "—" },
        { key = tr("row.tempmin"), value = "—" },
        { key = tr("row.tempmax"), value = "—" },
        { key = tr("row.wind"), value = "—" },
        { key = tr("row.elevation"), value = "—" },
        { key = tr("row.uv"), value = "—" },
        { key = tr("row.timezone"), value = "—" },
      },
    }),
  })

  local sunrise = trim(noctalia.getSetting("location.sunrise"))
  local sunset = trim(noctalia.getSetting("location.sunset"))
  local ephemeris = drawer.plate({
    key = "weather-ephemeris",
    caption = tr("caption.ephemeris"),
    note = tr("note.daily"),
    flexGrow = 1,
  }, {
    drawer.tabs({ key = "weather-tabs", labels = { tr("tab.daily"), tr("tab.hourly") }, index = 1 }),
    drawer.ledger({
      key = "weather-ephemeris-ledger",
      keyWidth = 120,
      cells = {
        { key = tr("row.sunrise"), value = (sunrise ~= nil and sunrise ~= "") and sunrise or "—" },
        { key = tr("row.sunset"), value = (sunset ~= nil and sunset ~= "") and sunset or "—" },
        { key = tr("row.daylight"), value = "—" },
      },
    }),
    ui.label({
      text = tr("weather.ephemeris.note"),
      fontSize = 12,
      fontFamily = "serif",
      color = T.paperDim,
      maxLines = 3,
    }),
  })

  return {
    ui.column({ key = "section-weather", gap = 12 }, {
      ui.row({ gap = 12, align = "stretch" }, {
        ui.column({ gap = 12, flexGrow = 1 }, { slip, readings }),
        ui.column({ gap = 12, flexGrow = 1 }, { ephemeris }),
      }),
    }),
  }
end

-- ---------------------------------------------------------------------------
-- VIII — Calendar: the month plate
-- ---------------------------------------------------------------------------

-- Builds the month grid: the label, whole weeks of day cells, and whether this
-- is the current month. `os.time` normalises an out-of-range month for us.
local function monthCells(offset)
  local now = os.date("*t")
  local first = os.time({ year = now.year, month = now.month + offset, day = 1, hour = 12 })
  local firstDate = os.date("*t", first)
  local year, month = firstDate.year, firstDate.month
  local length = tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0, hour = 12 })))
  local previousLength = tonumber(os.date("%d", os.time({ year = year, month = month, day = 0, hour = 12 })))
  local startColumn = ((firstDate.wday - 2) % 7) + 1

  local weeks = {}
  local week = {}
  for index = 1, startColumn - 1 do
    week[#week + 1] = {
      day = previousLength - (startColumn - 1 - index),
      inMonth = false,
      key = "lead-" .. tostring(index),
    }
  end
  for day = 1, length do
    week[#week + 1] = { day = day, inMonth = true, key = string.format("%04d-%02d-%02d", year, month, day) }
    if #week == 7 then
      weeks[#weeks + 1] = week
      week = {}
    end
  end
  if #week > 0 then
    local fill = 1
    while #week < 7 do
      week[#week + 1] = { day = fill, inMonth = false, key = "trail-" .. tostring(fill) }
      fill = fill + 1
    end
    weeks[#weeks + 1] = week
  end

  return {
    label = os.date("%B %Y", first),
    weeks = weeks,
    isCurrentMonth = year == now.year and month == now.month,
  }
end

local function calendarBody()
  local cells = monthCells(monthOffset)
  local today = os.date("*t")
  local todayEpoch = os.time(today)

  local headerRow = ui.row({ gap = 4, align = "center", justify = "space_between" }, {
    ui.button({
      key = "calendar-prev",
      glyph = "chevron-left",
      glyphSize = 15,
      variant = "ghost",
      tooltip = tr("action.previous"),
      onClick = function()
        monthOffset = monthOffset - 1
        render()
      end,
    }),
    ui.label({
      text = cells.label,
      fontSize = 17,
      fontWeight = "bold",
      fontFamily = "serif",
      color = T.bone,
      flexGrow = 1,
      textAlign = "center",
    }),
    ui.button({
      key = "calendar-next",
      glyph = "chevron-right",
      glyphSize = 15,
      variant = "ghost",
      tooltip = tr("action.next"),
      onClick = function()
        monthOffset = monthOffset + 1
        render()
      end,
    }),
  })

  local weekdayRow = {}
  for _, label in ipairs({ "weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat", "weekday.sun" }) do
    weekdayRow[#weekdayRow + 1] = ui.column({ flexGrow = 1, align = "center" }, {
      ui.label({ text = upper(tr(label)), fontSize = 9.5, fontFamily = "monospace", color = T.paperDim }),
    })
  end

  local weeks = {}
  for _, week in ipairs(cells.weeks) do
    local row = {}
    for column, day in ipairs(week) do
      local isToday = cells.isCurrentMonth and day.inMonth and day.day == today.day
      local color = T.bone
      if not day.inMonth then
        color = drawer.alpha(T.paperDim, 0.4)
      elseif column >= 6 then
        color = T.paperDim
      end
      if isToday then
        color = T.brassInk
      end
      row[#row + 1] = ui.column({
        key = "calendar-day-" .. day.key,
        flexGrow = 1,
        align = "center",
        paddingV = 5,
        radius = 3,
        fill = isToday and T.brass or nil,
      }, {
        ui.label({
          text = tostring(day.day),
          fontSize = 13,
          fontFamily = "serif",
          color = color,
          fontWeight = isToday and "bold" or nil,
        }),
      })
    end
    weeks[#weeks + 1] = ui.row({ gap = 1, align = "stretch" }, row)
  end

  local monthPlate = drawer.plate({
    key = "calendar-month",
    caption = tr("caption.monthplate"),
    flexGrow = 1,
  }, {
    headerRow,
    ui.row({ key = "calendar-weekdays", gap = 1, align = "stretch" }, weekdayRow),
    ui.column({ key = "calendar-weeks", gap = 2 }, weeks),
  })

  local calendarEnabled = noctalia.getSetting("calendar.enabled") == true
  local wallText = drawer.slip({
    key = "calendar-slip",
    stamp = tr("stamp.noevents"),
    title = tr("caption.walltext"),
    line = os.date("%A ", todayEpoch) .. tostring(today.day) .. os.date(" %B", todayEpoch) .. " — "
      .. (calendarEnabled and tr("calendar.enabled.body") or tr("calendar.disabled.body")),
    footerLeft = tr("row.gallery"),
    footerRight = tr("note.accessionpending"),
    flexGrow = 1,
  })

  return {
    ui.column({ key = "section-calendar", gap = 12 }, {
      ui.row({ gap = 12, align = "stretch" }, { monthPlate, wallText }),
    }),
  }
end

-- ---------------------------------------------------------------------------
-- IX — Notices: the accession drawer
-- ---------------------------------------------------------------------------

local function noticesBody()
  local list = notices()
  local counts = { 0, 0, 0, 0 }
  for _, notice in ipairs(list) do
    local age = tonumber(notice.age_days) or 0
    counts[1] = counts[1] + 1
    if age <= 0 then
      counts[2] = counts[2] + 1
    elseif age == 1 then
      counts[3] = counts[3] + 1
    else
      counts[4] = counts[4] + 1
    end
  end

  local tabs = {}
  for index, label in ipairs(NOTICE_TABS) do
    tabs[#tabs + 1] = upper(label) .. " " .. tostring(counts[index])
  end

  local kids = {
    drawer.tabs({
      key = "notices-tabs",
      labels = tabs,
      index = noticeFilter,
      onSelect = function(index)
        noticeFilter = index
        render()
      end,
    }),
  }

  local filed = 0
  for index, notice in ipairs(list) do
    local age = tonumber(notice.age_days) or 0
    local keep = noticeFilter == 1
      or (noticeFilter == 2 and age <= 0)
      or (noticeFilter == 3 and age == 1)
      or (noticeFilter == 4 and age > 1)
    if keep then
      filed = filed + 1
      local stamp = tostring(notice.stamp or "received")
      kids[#kids + 1] = drawer.slip({
        key = "notice-" .. tostring(index),
        stamp = stamp == "filed" and tr("stamp.filed") or tr("stamp.received"),
        tone = stamp == "filed" and "green" or "red",
        title = dash(notice.title),
        line = dash(notice.body),
        footerLeft = dash(notice.app) .. " · " .. tostring(age) .. "d",
        footerRight = "Acc. " .. string.format("%04d", index),
      })
    end
  end

  if filed == 0 then
    local unread = tonumber(noctalia.state.get("unread")) or 0
    kids[#kids + 1] = drawer.slip({
      key = "notices-empty",
      stamp = tr("stamp.empty"),
      title = tr("empty.notices"),
      line = unread > 0
        and (tostring(unread) .. " " .. tr("empty.notices.unread"))
        or tr("empty.notices.body"),
      footerLeft = tr("row.registry"),
      footerRight = unread > 0 and (tostring(unread) .. " " .. tr("note.unread")) or "—",
    })
  end

  return {
    ui.column({ key = "section-notices", gap = 10 }, kids),
  }
end

-- ---------------------------------------------------------------------------
-- X — Media: now exhibiting
-- ---------------------------------------------------------------------------

local function mediaBody()
  local media = feed.media or {}
  local length = tonumber(media.length)
  local position = tonumber(media.position)
  local progress = (length ~= nil and length > 0 and position ~= nil) and math.min(1, position / length) or nil
  local playing = media.status == "Playing"

  local label
  if media.title ~= nil and media.title ~= "" then
    local byline = dash(media.app or media.player)
    if media.artist ~= nil and media.artist ~= "" then
      byline = byline .. " · " .. media.artist
    end
    label = drawer.slip({
      key = "media-label",
      title = media.title,
      line = byline,
      footerLeft = tr("row.duration") .. " " .. clockText(length),
      footerRight = tr("row.elapsed") .. " " .. clockText(position),
    })
  else
    label = drawer.slip({
      key = "media-label",
      stamp = tr("stamp.empty"),
      title = tr("empty.exhibit"),
      line = tr("empty.exhibit.body"),
      footerLeft = tr("row.gallery"),
      footerRight = dash(media.status),
    })
  end

  local transport = ui.row({ key = "media-transport", gap = 8, align = "center" }, {
    ui.button({
      key = "media-previous",
      glyph = "player-skip-back",
      glyphSize = 16,
      variant = "secondary",
      tooltip = tr("action.previous"),
      onClick = function()
        request("media", { action = "previous" })
      end,
    }),
    ui.button({
      key = "media-playpause",
      glyph = playing and "player-pause" or "player-play",
      glyphSize = 16,
      variant = "primary",
      tooltip = playing and tr("action.pause") or tr("action.play"),
      onClick = function()
        request("media", { action = "play-pause" })
      end,
    }),
    ui.button({
      key = "media-next",
      glyph = "player-skip-forward",
      glyphSize = 16,
      variant = "secondary",
      tooltip = tr("action.next"),
      onClick = function()
        request("media", { action = "next" })
      end,
    }),
  })

  local wallLabel = drawer.plate({
    key = "media-walllabel",
    caption = tr("caption.walllabel"),
    note = media.status ~= nil and string.lower(media.status) or nil,
    flexGrow = 1,
  }, {
    label,
    drawer.bar({ key = "media-position", value = progress or 0, height = 8 }),
    transport,
  })

  local list = bands()
  local bars = {}
  for index = 1, 32 do
    local value = list and tonumber(list[index]) or 0
    bars[#bars + 1] = ui.box({
      key = "media-band-" .. tostring(index),
      flexGrow = 1,
      height = list and math.max(3, math.floor(value * 74)) or 2,
      radius = 1,
      fill = list and T.brass or drawer.alpha(T.brassDk, 0.5),
    })
  end

  local oscillograph = drawer.plate({
    key = "media-oscillograph",
    caption = tr("caption.oscillograph"),
    note = list and tr("note.bands") or tr("note.nosignal"),
    flexGrow = 1,
  }, {
    ui.row({
      key = "media-well",
      height = 90,
      align = "end",
      gap = 3,
      padding = 10,
      fill = T.walnut,
      radius = 3,
      border = T.brassDk,
      borderWidth = 1,
    }, bars),
    ui.box({ height = 1, fill = T.brass }),
  })

  return {
    ui.column({ key = "section-media", gap = 12 }, {
      ui.row({ gap = 12, align = "stretch" }, { wallLabel, oscillograph }),
    }),
  }
end

-- ---------------------------------------------------------------------------
-- The section switch
-- ---------------------------------------------------------------------------

local function sectionBody(section)
  if section.id == "system" then
    return systemBody()
  elseif section.id == "power" then
    return powerBody()
  elseif section.id == "audio" then
    return audioBody()
  elseif section.id == "display" then
    return displayBody()
  elseif section.id == "network" then
    return networkBody()
  elseif section.id == "bluetooth" then
    return bluetoothBody()
  elseif section.id == "weather" then
    return weatherBody()
  elseif section.id == "calendar" then
    return calendarBody()
  elseif section.id == "notices" then
    return noticesBody()
  elseif section.id == "media" then
    return mediaBody()
  end
  return {
    drawer.slip({
      key = "section-unknown",
      stamp = tr("stamp.empty"),
      title = tr("empty.wing"),
      line = tr("empty.wing.body"),
    }),
  }
end

-- The catalog line under a section title. Every wing gets a number of its own:
-- the specimen for System, the count of what the wing holds elsewhere.
local function accession(section)
  if section.id == "system" then
    return tr("accession.specimen") .. " " .. dash(feed.hostname)
  elseif section.id == "display" then
    return tostring(#(noctalia.outputs() or {})) .. " " .. tr("accession.lamps")
  elseif section.id == "audio" then
    return tr("accession.strips")
  elseif section.id == "network" then
    return tr("accession.registry")
  elseif section.id == "bluetooth" then
    return tr("accession.wireless")
  elseif section.id == "weather" then
    local address = trim(noctalia.getSetting("location.address"))
    if address == nil or address == "" then
      return tr("accession.nostation")
    end
    return address
  elseif section.id == "calendar" then
    return tr("accession.catno") .. " " .. os.date("%Y%m%d")
  elseif section.id == "notices" then
    return tostring(#notices()) .. " " .. tr("accession.accessions")
  elseif section.id == "media" then
    local media = feed.media or {}
    return dash(media.app or media.player)
  elseif section.id == "power" then
    return tr("accession.lighting")
  end
  return ""
end

-- ---------------------------------------------------------------------------
-- Rail, header, and the drawer
-- ---------------------------------------------------------------------------

local function rail()
  local items = {
    ui.label({
      key = "rail-head",
      text = upper(tr("rail.head")),
      fontSize = 8.5,
      fontWeight = "bold",
      fontFamily = "monospace",
      color = T.paperDim,
      maxLines = 1,
    }),
    ui.box({ height = 1, fill = drawer.alpha(T.brassDk, 0.6) }),
  }
  for index, section in ipairs(SECTIONS) do
    local on = index == active
    table.insert(items, ui.row({
      key = "rail-" .. section.id,
      gap = 8,
      align = "center",
      paddingH = 9,
      paddingV = 7,
      radius = 3,
      -- Always an explicit fill: the reconciler retains a native control across
      -- renders, and an omitted prop leaves the previous value in place. A
      -- nil here kept the old wing brass after the active wing moved.
      fill = on and T.brass or T.walnut2,
      onClick = function()
        active = index
        render()
      end,
    }, {
      ui.glyph({ name = section.glyph, size = 14, color = on and T.brassInk or T.bone }),
      ui.label({
        text = tr(section.name),
        fontSize = 12,
        color = on and T.brassInk or T.bone,
        fontWeight = on and "bold" or "normal",
        flexGrow = 1,
        maxLines = 1,
      }),
      ui.label({
        text = section.numeral,
        fontSize = 8.5,
        fontFamily = "monospace",
        color = on and drawer.alpha(T.brassInk, 0.75) or T.paperDim,
      }),
    }))
  end
  table.insert(items, ui.spacer({ flexGrow = 1 }))
  table.insert(items, ui.box({ height = 1, fill = drawer.alpha(T.brassDk, 0.6) }))
  table.insert(items, ui.label({
    text = upper(tr("rail.foot")),
    fontSize = 8,
    fontFamily = "monospace",
    color = drawer.alpha(T.paperDim, 0.8),
    maxLines = 2,
  }))

  return ui.column({
    key = "rail",
    width = 200,
    flexGrow = 0,
    fill = T.walnut2,
    padding = 11,
    gap = 2,
  }, items)
end

local function header(section)
  return ui.row({
    key = "drawer-header",
    align = "center",
    justify = "space_between",
    gap = 12,
    paddingH = 16,
    paddingV = 12,
  }, {
    ui.column({ gap = 3, flexGrow = 1 }, {
      ui.label({
        key = "drawer-title",
        text = tr(section.title),
        fontSize = 19,
        fontWeight = "bold",
        fontFamily = "serif",
        color = T.bone,
        maxLines = 1,
      }),
      ui.label({
        key = "drawer-accession",
        text = upper(accession(section)),
        fontSize = 8.5,
        fontWeight = "bold",
        fontFamily = "monospace",
        color = T.paperDim,
        maxLines = 1,
      }),
    }),
    ui.label({
      text = upper(tr("header.wing")) .. " " .. section.numeral,
      fontSize = 8.5,
      fontFamily = "monospace",
      color = drawer.alpha(T.paperDim, 0.8),
    }),
    ui.button({
      key = "header-refresh",
      glyph = "refresh",
      glyphSize = 15,
      variant = "ghost",
      tooltip = tr("action.refresh"),
      onClick = function()
        request("refresh")
      end,
    }),
    ui.button({
      key = "header-close",
      glyph = "x",
      glyphSize = 15,
      variant = "ghost",
      tooltip = tr("action.close"),
      onClick = function()
        panel.close()
      end,
    }),
  })
end

render = function()
  if not open then
    return
  end

  local section = SECTIONS[active]
  panel.render(ui.column({
    key = "museum-drawer",
    flexGrow = 1,
    fill = T.walnut,
    radius = 8,
    border = T.brassDk,
    borderWidth = 1,
    gap = 0,
  }, {
    ui.row({ flexGrow = 1, gap = 0, align = "stretch" }, {
      rail(),
      ui.box({ width = 1, fill = T.brassDk }),
      ui.column({ flexGrow = 1, gap = 0 }, {
        header(section),
        ui.box({ height = 1, fill = T.brassDk }),
        ui.scroll({
          key = "body-" .. section.id,
          flexGrow = 1,
          padding = 16,
          gap = 12,
        }, sectionBody(section)),
      }),
    }),
  }))
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function onOpen(context)
  open = true
  -- `noctalia msg panel-open cernoh/museum:panel audio` (or a shortcut that
  -- passes context) opens straight onto a wing: the context is a wing id.
  if context ~= nil then
    for index, section in ipairs(SECTIONS) do
      if section.id == context then
        active = index
      end
    end
  end
  feed = noctalia.state.get("drawer") or {}
  -- Open on the freshest record the service can give: it re-reads and
  -- republishes, and the watch below re-renders the drawer when it does.
  request("refresh")
  render()
end

function onClose()
  open = false
end

noctalia.state.watch("drawer", function(value)
  feed = value or {}
  render()
end)

noctalia.state.watch("notifications", function()
  render()
end)

noctalia.state.watch("bands", function()
  render()
end)

noctalia.state.watch("unread", function()
  render()
end)
