---
name: kindle-resolv-conf-and-dns
description: "Create or repair /etc/resolv.conf and DNS on a jailbroken Kindle reached over KOReader's dropbear (port 2222): the vendor symlink to a /var/run/resolv.conf that is never populated on 5.18.1, the real readers and writers, the resolv.d templates that are Lab126-internal, and the mntroot rw / e2fsck / reboot mechanics when the rootfs is dirty. Use when resolv.conf is missing, empty, or hijacked and Kindle DNS fails."
---

Fix DNS on a Kindle whose `/etc/resolv.conf` is missing, empty, or pointing at dead resolvers (for example stale tailscale `100.100.100.100`).

## Access
- `ssh -p 2222 root@<kindle-ip>` — KOReader's dropbear, no password. The IP moves with the DHCP lease; confirm identity with `cat /etc/prettyversion.txt`.
- The shell runs as uid 0 with the full capability set and the same mount namespace as PID 1, so `mntroot` and `e2fsck` are usable directly.
- `/` is `ro` in steady state. `mntroot rw` / `mntroot ro` toggle it. `/bin/mount` is busybox.

## Vendor DNS layout (Kindle 5.18.1)
- `/etc/resolv.conf` is normally a **symlink** to `/var/run/resolv.conf`, created by `/etc/upstart/firsttime:29`:
  `[ ! -L /etc/resolv.conf ] && mount_rw && ln -sf /var/run/resolv.conf /etc/resolv.conf`.
  The guard is `! -L`, so a **regular file** placed at that path is never replaced at boot — it persists.
- Readers and writers:
  - `/usr/share/udhcpc/default.script` (the DHCP script) writes DNS to **`/tmp/resolv.conf`** only (`/tmp -> /var/tmp`, tmpfs). `RESOLV_CONF="/tmp/resolv.conf"`.
  - `/usr/sbin/wifid` reads `/tmp/resolv.conf`, references `/var/run/resolv.conf`.
  - `/usr/sbin/cmd` reads and writes `/etc/resolv.conf`.
  - `/usr/sbin/odhcp6c-update` is the only thing that maintenance-writes `/var/run/resolv.conf` (IPv6 RA entries).
  - Nothing copies `/tmp/resolv.conf` into `/var/run/resolv.conf`.
- Observed 24 min after boot: `/tmp/resolv.conf` held `nameserver 192.168.1.1` while `/var/run/resolv.conf` was **0 bytes**. A restored symlink therefore resolves to an empty file, i.e. no DNS. This is why the working fix is a real file, not the vendor symlink.
- `/etc/resolv.d/resolv.conf.1..4`, `.default`, `.usbnetd` are Lab126/Amazon-internal templates (`172.22.130.x`, `10.189.9.x`, `207.171.165.x`, `156.154.7x.x`). Never copy those onto a user device.

## Fix
```sh
cat /tmp/resolv.conf          # the DHCP-supplied value; the source of truth
ip route                      # cross-check the gateway
mntroot rw
echo nameserver 192.168.1.1 > /etc/resolv.conf
chown root:root /etc/resolv.conf; chmod 0644 /etc/resolv.conf
sync
mntroot ro
nslookup www.google.com       # verification: must return addresses via that server
```
Keep the content identical to what DHCP supplied. Do not invent public resolvers — that is a behaviour change nobody asked for.

## When `mntroot rw` fails
`mount: / not mounted already, or bad option` plus dmesg `EXT4-fs (mmcblk0p8): Couldn't remount RDWR because of unprocessed orphan inode list. Please umount/remount block device` means the rootfs is dirty/error-flagged.
1. Diagnose read-only (safe on a live mount): `e2fsck -fn /dev/mmcblk0p8`. Look for `Entry '...' has deleted/unused inode`, `i_size is ... should be ...`, bitmap and free-count differences.
2. Repair: `e2fsck -fy /dev/mmcblk0p8`. It runs against the read-only-mounted fs; no unmount needed.
3. **Reboot before any write.** The kernel's buffer cache still holds pre-fsck metadata; writing through it resurrects the defect. Do not remount rw first.

## Traps
- Mount-flag cycling never converges. The blocker is on-disk/journal state, not mount options; `/dev/root` has no device node, so `mount -o remount,rw /` gives a misleading `not mounted already, or bad option`.
- busybox `mount` refuses a second mount of an already-mounted device (`/dev/mmcblk0p8 already mounted or <dir> busy`), so there is no shortcut to a fresh rw mount while `/` is mounted.
- While the rootfs is read-only, `mount -o bind /dev/null /etc/resolv.conf` gives an instant, reversible "removed" view (reads return 0 bytes). It lasts only until the next reboot or `umount`, and it does not delete the file.
- A bind of a file that lives on tmpfs shows up in `/proc/mounts` with source/type `tmpfs`, not the file path.
