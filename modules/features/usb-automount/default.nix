# USB automount feature: mounts removable filesystems under
# /run/media/<user>/<label> owned by the active graphical user, then sends a
# libnotify notification on mount AND unmount through that user's session bus.
#
# Design notes:
# - udev fires a templated systemd unit via SYSTEMD_WANTS instead of RUN+=;
#   long-running RUN+= children block further udev events.
# - Units triggered this way carry no udev environment variables, so the
#   helper distinguishes add/remove by checking whether the device node still
#   exists.
# - notify-send is referenced by its store path inside the helper, so the
#   module works even without libnotify in environment.systemPackages (the
#   core bundle installs it anyway).
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.usbAutomount = moduleWithSystem (
    {
      pkgs,
      self',
      ...
    }:
    {
      services.udev.extraRules = ''
        ACTION=="add|remove", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", TAG+="systemd", ENV{SYSTEMD_WANTS}="usb-automount@%k.service"
      '';

      systemd.services."usb-automount@" = {
        description = "USB automount + notification for %i";
        after = [ "systemd-udevd.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${self'.packages.usbAutomountHelper}/bin/usb-automount-helper %i";
        };
      };
    }
  );

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.usbAutomountHelper = pkgs.writeShellScriptBin "usb-automount-helper" ''
        set -eu

        name="$1"
        dev="/dev/$name"

        notify () {
          uid="$1"
          shift
          runuser -u "#$uid" -- env \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            ${pkgs.libnotify}/bin/notify-send -a "USB automount" "$@"
        }

        # UIDs owning an active graphical (user-class) session, one per line.
        active_uids () {
          loginctl list-sessions --no-legend 2>/dev/null |
          while read -r sid _; do
            [ -n "$sid" ] || continue
            state=$(loginctl show-session "$sid" -p State --value 2>/dev/null || true)
            class=$(loginctl show-session "$sid" -p Class --value 2>/dev/null || true)
            [ "$state" = "active" ] && [ "$class" = "user" ] || continue
            loginctl show-session "$sid" -p User --value
          done | sort -u
        }

        if [ -e "$dev" ]; then
          # ---- ADD ----
          if findmnt -rn -S "$dev" >/dev/null; then
            echo "usb-automount: $dev already mounted"
            exit 0
          fi

          label=$(lsblk -no LABEL "$dev" | head -n1)
          fstype=$(lsblk -no FSTYPE "$dev")

          uid=$(active_uids | head -n1)
          if [ -z "$uid" ]; then
            echo "usb-automount: no active graphical session, skipping $name" >&2
            exit 1
          fi
          user=$(id -nu "$uid")
          gid=$(id -ng "$uid")

          label=''${label:-$name}
          safe=$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')
          mnt="/run/media/$user/$safe"

          # uid=/gid=/umask= are rejected by native-Linux filesystems; only pass
          # them where the kernel would otherwise assign everything to root.
          opts=""
          case "$fstype" in
            vfat|exfat|ntfs|ntfs3|fuseblk) opts="uid=$uid,gid=$gid,umask=022" ;;
          esac

          mkdir -p "$mnt"
          chown "$uid:$gid" "$mnt"

          if mount ''${opts:+-o "$opts"} -t "''${fstype:-auto}" "$dev" "$mnt"; then
            notify "$uid" "USB mounted" "$label mounted at $mnt"
          else
            rmdir "$mnt" 2>/dev/null || true
            notify "$uid" -u critical "USB mount failed" "Could not mount $label ($name)"
            exit 1
          fi
        else
          # ---- REMOVE ----
          # The node is gone, so there is nothing left to unmount; a yanked
          # drive relies on prior kernel writeback having completed.
          for uid in $(active_uids); do
            notify "$uid" "USB unplugged" "$name removed"
          done
        fi
      '';
    };
}
