# Time sync ported from the Mac's pre-dendritic configuration.nix: chrony
# plus a one-shot that force-steps the clock when chronyd comes up unsynced
# after a network change (Apple Silicon boxes have no RTC battery drift
# guard, so boot-time jumps were real).
{
  ...
}:
{
  flake.nixosModules.timeSync =
    {
      pkgs,
      lib,
      ...
    }:
    {
      services.chrony = {
        enable = true;
        servers = [
          "129.6.15.28"
          "time.cloudflare.com"
          "time.google.com"
        ];
      };

      # Force time sync on network connection (verbatim behaviour from the
      # old configuration.nix).
      systemd.services.chrony-time-sync = {
        description = "Force chrony time sync on network connection";
        after = [
          "network-online.target"
          "chronyd.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "chrony-time-sync" ''
            # Wait a moment for chronyd to stabilize
            sleep 2

            # Check if chrony is tracking (synchronized)
            TRACKING_STATUS=$(${pkgs.chrony}/bin/chronyc tracking 2>/dev/null | grep "Leap status" | awk '{print $4}')

            # If not synchronized or in normal state with issue, force sync
            if [ "$TRACKING_STATUS" = "Not synchronised" ] || [ -z "$TRACKING_STATUS" ]; then
              echo "Time not synchronized, running chronyc makestep..."
              ${pkgs.chrony}/bin/chronyc makestep
            else
              echo "Time already synchronized (status: $TRACKING_STATUS)"
            fi
          '';
        };
      };
    };
}
