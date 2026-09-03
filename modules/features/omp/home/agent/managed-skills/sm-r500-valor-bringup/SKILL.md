---
name: sm-r500-valor-bringup
description: Bring up Galaxy Watch Active SM-R500 (valor/Exynos 9110) via wireless netOdin FT40 rootfs and AsteroidOS mainline track
---

# SM-R500 Valor Bring-up

Galaxy Watch Active SM-R500 (valor/hawk, Exynos 9110, Tizen 5.5.0.2 EOL). No public custom kernel/ROM/WearOS. Only Tizen rootfs mod via engineer sboot + AsteroidOS mainline is feasible.

## Quick facts
- SoC: Exynos 9110 SiP-ePoP, dual A53 1.15GHz, Mali-T720 MP1 (lima), 768MiB/4GiB eMMC, BCM43013 BT4.2/WiFi, MAX86902 HR, S2MPS PMIC, Qi-only sealed.
- Kernel: downstream 4.4.111 `exynos9110-pulse_defconfig`, no upstream `exynos9110.dtsi`.
- Partitions mmcblk0: p8 boot 16.8M, p9 recovery, p11 csc OXA, p14 rootfs ~1G, p1 tup p2 csa p3 cpnvcore p4/5 ramdisk p6 param p7 cm p12 system-data p13 user p15 steady.
- Secure boot: iROM→BL2→S-BOOT eFuse verified. No 9110 BootROM exploit (exynos-usbdl 8890/8895 only). Knox + anti-rollback fuse.
- Flash: WIRELESS netOdin only (Heimdall USB unreliable, cradle pogo erratic). AP mode via `wd_cm_set_ap_mode`.

## Host flake
`flake.nix` provides:
- `nix develop` (default) + `#asteroid` (Yocto) + `#postmarket`
- Helpers: `fetch-r500-kernel [--guide|--fota] <url> [out]`, `sdb-wrap`, `netodin-note`, `check-r500`, `mk-bootimg`, `build-r500-kernel [k-dir]`, `flash-r500 <img>`
- Cross: `pkgsCross.armv7l-hf-multiplatform` + `aarch64-multiplatform`, `ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-`

Fix: use `armv7l-hf-multiplatform` not `armv7l-hf` (nixpkgs 26.11pre).

## Simple rootfs (days)
1. Get `Settings → About watch → Software version` = `R500XXU1XXXX` (e.g. GVG1/GVI3/HWI1). Serial RFAN... is not SW REV. Check `SW REV` on Download screen for anti-rollback.
2. Fetch 3-file OXA stock for that build (SamMobile/SamFW/XDA `.../galaxy-watch-activ-firmware-r500.3941317/`) + FT40 combo `R500XXU1ASA5`/`ASG1` (XDA `.../rooting-samsung-galaxy-watch-active.4003247/` = engineer sboot + rooted rootfs). Keep stock tarball = unbrick.
3. Wireless Download: Power off → hold Home → DOWNLOAD (WIRELESS) → note AP SSID/pass → join from host → netOdin (Win or Linux netOdin3 port) flash FT40. Risk: FT40 2019 < GVG1 2022, ensure SW REV allows; return to same-rev OXA is safe.
4. `sdb connect <watch-ip>` (or cradle) → `sdb root on && sdb shell "ls -l /dev/mmcblk0p*; id"` → `sdb pull /dev/mmcblk0p14 ./rootfs-<build>.img` + p8 boot.
5. Patch rootfs (`device-profile.xml`, `usr/share/cert-svc`, `sdb install app.tpk`) → `mk-bootimg`/`build-r500-kernel` repack → netOdin re-flash p14/p8. Return to stock: netOdin flash OXA same/newer rev.

## FOTA inspection
`fetch-r500-kernel --fota` clones `lapinclown/SM-R500-TizenFOTA-pkgs` (BSD3/DTG2/FUB5/GUJ2/GVG1). `7z e -so .../*.7z | tar tv` shows delta set (`delta.boot`, `rootfs.img/*.delta`, `csc.img/*`) — delta-only, not full images.

## AsteroidOS mainline (months)
- Fetch OSRC: `opensource.samsung.com → Mobile → Wearable/IoT → SM-R500` (API `.../api/search?searchValue=SM-R500` is Cloudflare-challenged) → `fetch-r500-kernel "https://...SM-R500_...tar.gz" ./sources` → verify `VERSION=4 PATCHLEVEL=4 SUBLEVEL=111` → extract `arch/arm*/dts/exynos9110*.dts` + `exynos9110-pulse_defconfig`.
- Template: `HonestlyAnnoying/tizen_kernel_exynos7270` (7270, 3.18) for Makefile/mkbootimg flow.
- Author `exynos9110.dtsi` (clocks `clk-exynos9110.c`, PMU, PM domains, decon/MIPI 360×360, dw_mmc, brcmfmac/btbcm BCM43013, S2MPS/MUIC/Qi, sensorhub M0/MAX86902).
- Layer `meta-r500` from `AsteroidOS/meta-smartwatch` (27 machines, no valor): `conf/machine/valor.conf`, `linux-valor_4.4.bb`, `sensorfw`/`mce` appends, `lima` for T720, iterate via netOdin p8 (no fastboot).
- Bring-up order: boot shell → exynos-drm/lima → lipstick (rinato sluggish precedent) → dw_mmc/mce/Qi → BCM43013/NFC/sensorfw.

## Sources
XDA firmware/root threads, opensource.samsung.com, semiconductor.samsung.com/exynos-9110, asteroidos.org/watches + wiki Porting_Guide/Rinato, HonestlyAnnoying 7270, lapinclown FOTA.
