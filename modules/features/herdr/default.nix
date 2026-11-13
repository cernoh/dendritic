# herdr feature — the herdr daemon itself, and the only thing that starts it.
#
# herdr is a terminal-workspace multiplexer: one long-lived server per user,
# exposed on `~/.config/herdr/herdr.sock`. Every client attaches to that one
# server — the `herdr` TUI, both web bridges, the Wayfinder relay, and the
# agent panes pi-cowboy spawns.
#
# Somebody has to own it, and "whoever attaches first" is the wrong answer.
# A client started by systemd inherits a *minimal* environment: the
# `herdr-web` unit declares only herdr, zoxide, findutils, iproute2 and
# coreutils in its PATH, so the server it spawned had no `git`. herdr's
# worktree runtime shells out for every worktree operation and has no
# in-process git (its Cargo.toml pulls no gix/git2), so `herdr worktree
# list`, `open` and `create` all failed with `No such file or directory
# (os error 2)` — and pi-cowboy, whose agents are git worktrees, could not
# spawn a single one. This feature makes the daemon a unit in its own right,
# so the environment it runs with is declared here rather than falling out of
# whichever client happened to start it first.
#
# What the daemon needs on PATH, and why exactly this much:
#   - `git` — load-bearing. herdr runs `git worktree list --porcelain`,
#     `git worktree add`/`remove`, and `git -C <repo> rev-parse …` for
#     worktrees, status and repo discovery, all through
#     `noninteractive_process::command("git")` — a plain PATH lookup.
#   - `curl` — the server-side update/announcement fetch (`src/update.rs`).
#   - `coreutils` — base utilities, plus the `sleep` the readiness probe uses.
# Deliberately NOT here: anything only the *panes* need. Panes inherit this
# PATH, but their shell comes from `/etc/passwd` and rebuilds PATH from its
# own rc files, and the bridges' helpers (`zoxide`, `find`, `ss`) belong to
# those units. `herdr integration`'s version probes also resolve against this
# PATH, so an agent binary (`pi`, `claude`, …) that should report a version
# has to be listed here — add one only when that is actually wanted.
#
# Why `default.target` and not `graphical-session.target`: this user manager
# already has the session imported (`systemctl --user show-environment` shows
# WAYLAND_DISPLAY, DBUS_SESSION_BUS_ADDRESS, XDG_CURRENT_DESKTOP), so panes get
# a working Wayland and D-Bus environment without binding the daemon to the
# desktop session — which keeps it reachable from an SSH-only session too.
# The session env reaches panes through here either way.
#
# Two facts about the daemon's lifecycle shape this unit:
#   - A second `herdr server` exits 1 with "herdr server is already running"
#     while another one owns the socket, so `Restart=on-failure` alone would
#     spin. The start limits below cap that at three attempts in a minute, and
#     the journal then says why. This is the one state worth knowing about: a
#     *stray* server that an old client spawned detached (herdr-web falls back
#     to exactly that when its ping fails) is not owned by systemd, so `stop`
#     it once by hand — see the cutover note in the module body.
#   - A deliberate `herdr server stop` exits 0, so `on-failure` correctly does
#     not resurrect a server the user stopped on purpose.
#   - A crash (SIGKILL) leaves the socket file behind, and the daemon handles
#     that itself: it unlinks and rebinds a stale socket on the next start. The
#     restart path therefore needs no cleanup step.
#
# The package stays in `environment.systemPackages` (`attrs/desktop`) rather
# than here: herdr is installed on both desktop hosts and used interactively
# without any daemon ownership question, and this module is imported by the
# hosts that want the managed daemon. The overlay that makes herdr link
# (`attrs/desktop`, lld for the zig-built libghostty-vt) is system-wide, so
# `pkgs.herdr` here is the same fixed build.
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.homeManagerModules.herdr = moduleWithSystem (
    _:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.herdr;
      herdr = lib.getExe' cfg.package "herdr";

      # Readiness gate, not a health check: `ExecStartPost` holds the start job
      # open until the API socket answers, so a dependent unit ordered
      # `After=herdr.service` is guaranteed a live server. Without it, "started"
      # means only "forked", and `herdr-web`'s ping-then-spawn would find no
      # server and spawn its own detached one — the arrangement this feature
      # exists to remove.
      #
      # `herdr agent list` is the probe because it is the cheapest CLI call that
      # needs the socket and nothing else: it exits 1 when no server answers and
      # 0 when one does, where `herdr status` exits 0 either way (it reports the
      # absence) and `herdr worktree list` would drag git and a git repo into a
      # readiness test. That makes it a strict superset of the `ping` method
      # herdr-web itself uses to decide whether to spawn.
      waitReady = pkgs.writeShellScript "herdr-wait-ready" ''
        set -eu
        for ((i = 0; i < 60; i++)); do
          if ${herdr} agent list >/dev/null 2>&1; then
            exit 0
          fi
          sleep 0.5
        done
        echo "herdr server did not answer on the API socket within 30s" >&2
        exit 1
      '';
    in
    {
      options.services.herdr = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.herdr;
          defaultText = lib.literalExpression "pkgs.herdr";
          description = "The herdr package whose `server` this unit runs.";
        };
      };

      config = {
        systemd.user.services.herdr = {
          Unit = {
            Description = "herdr: persistent terminal-workspace server";
            Documentation = [ "https://herdr.dev" ];
            # A competing server exits 1 immediately; try a few times (a crash
            # restart is legitimate) and then stop rather than loop forever.
            StartLimitIntervalSec = 60;
            StartLimitBurst = 3;
          };

          Service = {
            Type = "simple";
            # The socket lives at the default `~/.config/herdr/herdr.sock`;
            # nothing here overrides HERDR_SOCKET_PATH, so every client and
            # bridge finds the same server.
            ExecStart = "${herdr} server";
            ExecStartPost = "${waitReady}";
            Environment = [
              "PATH=${
                lib.makeBinPath (
                  with pkgs;
                  [
                    git
                    curl
                    coreutils
                  ]
                )
              }"
            ];
            Restart = "on-failure";
            RestartSec = 5;
          };

          Install.WantedBy = [ "default.target" ];
        };
      };
    }
  );

  # ---------------------------------------------------------------------------
  # NixOS module — the enable switch for the host.
  # ---------------------------------------------------------------------------
  # Importing this aspect is the whole switch: the daemon is a user service, so
  # the home-manager half is injected here rather than listed in
  # `system/home-manager`'s all-host set. That keeps the scope a host decides:
  # NIXPC imports it today, and adding it to another host means one import
  # line, with no service or package reaching a host that did not ask for it.
  flake.nixosModules.herdr = _: {
    config.home-manager.sharedModules = [ self.homeManagerModules.herdr ];
  };
}
