---
name: wireplumber-mute-flap-diagnosis
description: "Diagnose and fix a PipeWire/WirePlumber default-sink that mutes/unmutes by itself (audio chopping, volume keys seeming dead) on NixOS hosts, including the WirePlumber debug-log capture recipe and the api.alsa.soft-mixer fix for USB cards whose only mixer control is an INV_BOOLEAN switch"
---

# Symptom signature

"Volume keeps glitching out" on a Linux/Wayland desktop usually means one of four things.
Separate them first, or you will fix the wrong layer:

1. The sink **mute state toggles by itself** at 1-10 Hz (audio chopped).
2. The **default sink changes** (USB re-enumeration, HDMI fallback).
3. **Crackle/pops** with a stable state (xruns, power-save, hw mixer steps).
4. The **keys do nothing** (compositor binding, wrong default node).

Fastest discriminator: sample the mute state and watch for state changes.

```bash
S=$(pactl list short sinks | awk '$2 ~ /<sink-name-fragment>/ {print $1}')
prev=""; flips=0; end=$((SECONDS+45))
while [ $SECONDS -lt $end ]; do
  m=$(pactl get-sink-mute "$S")
  [ -n "$prev" ] && [ "$m" != "$prev" ] && { flips=$((flips+1)); echo "$(date +%H:%M:%S) $m"; }
  prev="$m"; sleep 0.05
done
echo "flips=$flips"
```

# Triage

- Keybinding handler is the actor? Count `wpctl` processes at each flip:
  `pgrep -x wpctl` inside the sampling loop. Zero processes at a flip means the
  change comes from a PipeWire client or the session manager, not the binding.
- Shell (Noctalia/Waybar) is the actor? Stop the shell service, sample again.
  Flapping that continues or worsens rules the shell out.
- Device flap? `journalctl -b | grep -E 'usb [0-9-]+: (USB disconnect|new .* USB device)'`
  and compare the port the card lives on now: `readlink -f /sys/class/sound/card<N>/device`.
- Xruns? `timeout 12 pw-top -b -n 2` - read the `ERR` column. Non-zero ERR with a
  stable mute state points at the driver/period path, not at mute state.
- hw mixer in use? `pw-dump` and look at the device's `Route` param `info` array for
  `route.hw-mute` / `route.hw-volume` and at `props.volumeBase`.

# Capture the actor: WirePlumber debug logging

The decisive evidence. Loop chain repeats verbatim during a burst:

```
spa.alsa [acp.c:2356:acp_device_set_mute]: Set hardware mute: 1
spa.alsa [alsa-acp-device.c:1086:on_mute_changed]: device analog-stereo mute changed
s-device [state-routes.lua:256:chunk]: storing route(<route>) props of device(<card>)
s-default-nodes [apply-default-node.lua:34:chunk]: set default node for default.audio.sink <node>
```

```bash
systemctl --user set-environment WIREPLUMBER_DEBUG=D
systemctl --user restart wireplumber
# capture a burst (see sampler above), then:
journalctl --user -u wireplumber --since '2026-01-01 00:00:00' --no-pager | grep -E 'mute|storing route'
# afterwards ALWAYS:
systemctl --user unset-environment WIREPLUMBER_DEBUG
systemctl --user restart wireplumber
```

Bursts are intermittent (seconds long, one per minute to one per 10 minutes), so a
quiet window proves nothing. The log signature is the reliable detector.

# Root cause and fix

Chain: WirePlumber writes the card's hardware mute switch -> device reports the
change -> `state-routes.lua` stores the route props -> the route is re-applied ->
the switch is written again. When the card's only mixer control is a switch with the
`INV_BOOLEAN` flag (`/proc/asound/card<N>/usbmixer`, cheap AB13X/`Generic USB Audio`
dongles), the read-back polarity never matches, so the cycle never converges.

Fix: force software mute/volume for that card only, so PipeWire never touches the
switch. NixOS:

```nix
services.pipewire.wireplumber.extraConfig."51-usb-audio-soft-mixer" = {
  "monitor.alsa.rules" = [
    {
      matches = [ { "device.name" = "~alsa_card.usb-<Name>.*"; } ];
      actions."update-props"."api.alsa.soft-mixer" = true;
    }
  ];
};
```

Notes:
- Match `device.name` (the ACP device owns the mute control). Matching `node.name`
  does not reach the device object.
- `extraConfig` is `attrsOf (attrsOf json.type)`; each entry becomes
  `share/wireplumber/wireplumber.conf.d/<name>.conf` with `section = <JSON>`.
- Live test without rebuilding: drop the same SPA-JSON into
  `~/.config/wireplumber/wireplumber.conf.d/99-<name>.conf` and restart
  `wireplumber`. Remove the drop-in once the flake change is deployed.

Verify:

```bash
pw-dump > /tmp/pw.json   # then inspect the device's Route info array
# expect: "route.hw-mute","false","route.hw-volume","false" and props.volumeBase 1.0
# on this host: previously "true","true" with volumeBase 0.031621
```

Then re-run the sampler: 0 flips and 0 `Set hardware mute` log lines.
`wpctl set-mute` toggles on the node do NOT produce `Set hardware mute` writes even
without the fix, so mute toggles are a weak probe; the route flags are the strong one.

# Global alternative and its cost

`wireplumber.settings = { device.restore-routes = false; }` also breaks the loop
(removes the `storing route` step; 0 flips / 0 hw-mute writes over 90 s) but disables
route-props restore for every device, so per-route volume is not restored on session
start. Prefer the per-card soft-mixer rule.

# Cleanup

Restore the user's session when done:
- Unmute/unmute-as-before: `wpctl set-mute @DEFAULT_AUDIO_SINK@ 0`, restore volume.
- `wpctl set-volume` steps are exact 5%, so a value not on a 5% boundary snaps: 0.89
  comes back as 0.80 after four `5%-` operations. Set the target value directly.
- Remove any temporary drop-in and scripts; unset `WIREPLUMBER_DEBUG`.
