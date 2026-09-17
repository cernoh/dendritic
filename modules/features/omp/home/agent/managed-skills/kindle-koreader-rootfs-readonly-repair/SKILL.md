---
name: kindle-koreader-rootfs-readonly-repair
description: "Diagnose and repair a Kindle/KOReader rootfs that is stuck read-only (ext4 orphan/error state, mntroot rw failing), and delete or mask files on it. Use when an SSH session on a Kindle cannot write to /, when mount -o remount,rw / fails with \"not mounted already, or bad option\", or when dmesg shows \"Couldn't remount RDWR because of unprocessed orphan inode list\"."
---

# Kindle (KOReader) read-only rootfs: diagnose, repair, write

## Environment facts

- SSH into a Kindle usually lands in **KOReader's dropbear**, not the system daemon:
  `./dropbear -E -R -p2222 -P /tmp/dropbear_koreader.pid -n`, started by `/var/tmp/koreader.sh`.
  Port 2222, `root`, no password, full capabilities (`CapEff: 0000003fffffffff`).
- Root device is **`/dev/mmcblk0p8`** (superblock is ext4; the kernel mounts it with the
  ext3 compat driver, so `/proc/mounts` says `ext3`). There is **no `/dev/root` node**,
  which is why remounts that pass `/dev/root` mismatch.
- Kindle mounts root **read-only** at boot; `/usr/sbin/mntroot rw` / `mntroot ro` is the
  vendor helper (`mntroot` is a shell script around `mount -o remount,rw /`).
- Writability map when root is ro:
  - `/var` tmpfs rw, `/var/local` (`mmcblk0p9`) ext3 rw, `/mnt/us` fuse rw, `/dev` tmpfs rw.
  - `squashfs` loops under `/usr/lib/...`, `/etc/kdb.src`, etc. are permanently ro.
- Tooling: `/bin/mount` is **busybox**. No `python`, `perl`, `fsck` in busybox applets.
  `/sbin/e2fsck` (e2fsprogs 1.46.4) **is** present, plus `fsck.ext4`, `dosfsck`.
  `/var/tmp/chroot` is a tmpfs scaffold with bind mounts from the root fs, not an escape hatch.

## Symptom

```
$ mount -o remount,rw /dev/mmcblk0p8 /
mount: / not mounted already, or bad option         # rc=32
$ rm -f /etc/resolv.conf
rm: can't remove '/etc/resolv.conf': Read-only file system
```

Vendor helper fails identically:

```
$ mntroot rw
system: I mntroot:def:Making root filesystem writeable
mount: / not mounted already, or bad option
system: E mntroot:def:Re-mounting root filesystem failed
```

Ground truth is in `dmesg` (works as root here):

```
EXT4-fs error (device mmcblk0p8): ext4_lookup:1617: inode #5456: comm mount: deleted inode referenced
EXT4-fs (mmcblk0p8): Couldn't remount RDWR because of unprocessed orphan inode list.
Please umount/remount block device mmcblk0p8
```

Also check capabilities before blaming the fs — a dropbear that drops `CAP_SYS_ADMIN`
produces the same remount failure:

```
grep -E 'Cap(Eff|Prm|Bnd)' /proc/self/status
```

## Root cause

The root fs was not cleanly unmounted. With root mounted **ro**, ext4 never replays the
journal, so the in-memory `EXT4_ORPHAN_FS` state persists and the kernel refuses
`MS_REMOUNT` to rw (`EINVAL`), telling you to umount/remount — which you cannot do for `/`.

The on-disk superblock can look innocuous and mislead you:

```
dd if=/dev/mmcblk0p8 bs=1 skip=1082 count=2 | od -An -tu1   # s_state  -> 3 = VALID_FS|ERROR_FS
dd if=/dev/mmcblk0p8 bs=1 skip=1252 count=4 | od -An -tu1   # s_last_orphan -> 0
```

`s_last_orphan = 0` does **not** mean the fs is clean: with a journal, the live superblock
and orphan ledger sit in the journal until replay.

Do **not** try to defeat the busybox "already mounted" guard:
- a second live rw mount of `mmcblk0p8` runs journal replay + orphan cleanup under a live
  ro superblock → rootfs corruption risk;
- a loop device over the same partition splits the page cache the same way.

## Diagnose (safe, works on a ro-mounted fs)

```
e2fsck -fn /dev/mmcblk0p8
```

Typical output that explains the failure:

```
Inode 273, i_size is 16384, should be 17408.  Fix? no
Deleted inode 9637 has zero dtime.  Fix? no
Entry 'blkid.tab' in /etc (5456) has deleted/unused inode 9637.  Clear? no
Block bitmap differences:  -431246 -433281
Inode bitmap differences:  -(9636--9637)
/dev/mmcblk0p8: ********** WARNING: Filesystem still has errors **********
```

## Repair

Get explicit user approval first: this rewrites the filesystem on a live device and a power
loss mid-run can destroy the rootfs.

```
sync
e2fsck -fy /dev/mmcblk0p8
```

It ends with `***** FILE SYSTEM WAS MODIFIED *****` / `***** REBOOT SYSTEM *****`
(exit code 3). Confirm with `e2fsck -fn /dev/mmcblk0p8`; a clean pass prints only the
Pass 1-5 headers and the summary line.

**Then stop and let the user reboot.** The `rw` remount will succeed immediately after the
fsck, but the kernel buffer cache still holds pre-fsck copies of the superblock, the
bitmaps and `/etc`'s directory block. Any write before the reboot can restore the stale
dirent and re-corrupt the fs. If you must leave the device, remount back to `ro`
(`mount -o remount,ro /dev/mmcblk0p8 /`) so background framework processes cannot write
through the stale cache. The `REBOOT SYSTEM` marker means the fsck is not complete until
the machine restarts.

After the reboot: `mntroot rw` succeeds, do the write, then `mntroot ro`.

## Mask a file when root must stay ro

If the fs cannot be repaired right now, remove the file from every process's view without
writing:

```
mount -o bind /dev/null /etc/resolv.conf   # reads 0 bytes; /proc/mounts shows tmpfs source
umount /etc/resolv.conf                    # undo
```

Runtime-only: it vanishes on reboot and the original on-disk file is untouched. Never
overmount a whole directory (`mount -t tmpfs tmpfs /etc`) — that hides `passwd`, `hosts`, etc.

## Note on tailscale

Kindle `resolv.conf` hijacks come from tailscale:

```
# resolv.conf(5) file generated by tailscale
nameserver 100.100.100.100
nameserver fd7a:115c:a1e0::53
search tail<id>.ts.net
```

tailscaled writes this when root is rw; if root is ro, the daemon cannot regenerate it, so
a deletion normally sticks until the next rw window. Check whether the daemon is even
running before planning around it.

## Verification

```
grep ' / ' /proc/mounts          # expect the ro/rw flag you intended
e2fsck -fn /dev/mmcblk0p8        # clean pass after repair
cat /etc/resolv.conf             # empty when masked
wc -c < /etc/resolv.conf         # 0 when masked
```
