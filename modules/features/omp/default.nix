# Oh My Pi (omp) feature — prebuilt binary from GitHub releases with auto-update.
#
# Formerly consumed `can1357/oh-my-pi` as a flake input and built from
# Rust+Bun source via `inputs.oh-my-pi.overlays.default`. Now pulls the
# prebuilt binary from `github.com/can1357/oh-my-pi/releases` — no flake
# input, no build. Because dendritic's deploys are already `--impure`
# (hardwareFromMachine), both the nix package and the HM activation track
# `releases/latest` by default — no manual version/hash bumps.
#
# - Binary package is `perSystem.packages.omp` (`_omp.pkg.nix`) with
#   `autoUpdate = true` (default). It impurely fetches
#   `releases/latest/download/<asset>` via `builtins.fetchurl` (no hash)
#   and resolves `version` from the GitHub API. Set `autoUpdate = false`
#   to use the pinned `version` + SRI hashes.
# - `overlays.omp` / `overlays.default` expose the same binary as a
#   nixpkgs overlay (`pkgs.omp`).
# - `flake.nixosModules.omp` / `flake.homeManagerModules.omp` (plus
#   `oh-my-pi` compat aliases) provide `programs.omp` with `package`,
#   `settings`, and `useLatestBinary` (default true). When true, the
#   module also downloads `releases/latest` imperatively to
#   `~/.local/bin/omp.bin` (pristine) + `~/.local/bin/omp` (loader
#   wrapper) on each activation — true auto-update without waiting for
#   a rebuild. The nix package itself already auto-updates.
# - Linux binaries are Bun single-file executables and must stay pristine:
#   both the nix package and the activation scripts ship the untouched
#   download and exec it through the Nix glibc loader from a small
#   wrapper (rewriting INTERP/RPATH with patchelf corrupts the embedded
#   payload lookup → SIGSEGV at startup).
# - HM module keeps dendritic's out-of-store `~/.omp` symlink (same pattern
#   as home-manager-v3: tracked config lives in ./home, runtime state —
#   dbs, sessions, logs — is written live into this checkout). The symlink
#   target is the feature's `home/` directory inside THIS repo.
# - Declares current non-secret settings (from home/agent/config.yml and
#   home/agent/mcp.json, 2026-09-03) via `programs.omp.settings` and
#   `home.activation.ompMcp` — no API keys/tokens in Nix; provide
#   secrets via env / sops-nix / credential store.
#
# Opt in:
#   imports = [ self.homeManagerModules.omp ];
# then either `programs.omp.enable = true` or the compat `programs.oh-my-pi.enable`.
# Auto-update is on by default; to pin:
#   programs.omp.useLatestBinary = false;  # plus perSystem autoUpdate = false if you want pure
{ self, ... }:
{
  # ---------------------------------------------------------------------------
  # Overlay: expose prebuilt binary as `pkgs.omp`.
  # ---------------------------------------------------------------------------
  flake.overlays.omp = final: _prev: {
    omp = self.packages.${final.stdenv.hostPlatform.system}.omp;
  };
  flake.overlays.default = final: _prev: {
    omp = self.packages.${final.stdenv.hostPlatform.system}.omp;
  };

  # ---------------------------------------------------------------------------
  # NixOS modules — `programs.omp` with binary package.
  # ---------------------------------------------------------------------------
  flake.nixosModules.omp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.programs.omp = {
        enable = lib.mkEnableOption "Oh My Pi (omp) — prebuilt binary from GitHub releases";
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
          description = "OMP package (prebuilt GitHub release binary). Set to null with useLatestBinary to fetch latest imperatively.";
        };
        useLatestBinary = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "When true, also download latest release binary to /usr/local/bin/omp via activation (curl releases/latest) for instant auto-update. Package itself already auto-updates (--impure). Set false to pin.";
        };
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "OMP settings merged into ~/.omp/agent/config.yml (YAML).";
        };
      };
      options.programs.oh-my-pi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Alias for programs.omp.enable (compat).";
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Alias for programs.omp.package.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf config.programs.oh-my-pi.enable { programs.omp.enable = true; })
        (lib.mkIf (config.programs.oh-my-pi.package != null) {
          programs.omp.package = config.programs.oh-my-pi.package;
        })
        (lib.mkIf config.programs.omp.enable {
          environment.systemPackages = lib.optionals (config.programs.omp.package != null) [
            config.programs.omp.package
          ];
        })
        (lib.mkIf (config.programs.omp.enable && config.programs.omp.useLatestBinary) {
          system.activationScripts.ompLatestBinary = {
            text = ''
              # Activation PATH is minimal — pin fetchers and friends to the store.
              export PATH="${
                lib.makeBinPath [
                  pkgs.curl
                  pkgs.wget
                  pkgs.coreutils
                ]
              }:$PATH"
              mkdir -p /usr/local/bin
              asset=""
              os=$(uname -s 2>/dev/null || echo Linux)
              arch=$(uname -m 2>/dev/null || echo x86_64)
              case "$os-$arch" in
                Linux-x86_64|Linux-x86-64) asset="omp-linux-x64" ;;
                Linux-aarch64|Linux-arm64) asset="omp-linux-arm64" ;;
                Darwin-x86_64|Darwin-x86-64) asset="omp-darwin-x64" ;;
                Darwin-arm64|Darwin-aarch64) asset="omp-darwin-arm64" ;;
                *) asset="omp-linux-x64" ;;
              esac
              url="https://github.com/can1357/oh-my-pi/releases/latest/download/$asset"
              dest="/usr/local/bin/omp"
              bin="/usr/local/bin/omp.bin"
              # Activation PATH is minimal — use store absolute paths.
              if ${pkgs.curl}/bin/curl -fsSL "$url" -o "$bin.tmp" 2>/dev/null; then
                chmod +x "$bin.tmp" || true
              elif ${pkgs.wget}/bin/wget -qO "$bin.tmp" "$url" 2>/dev/null; then
                chmod +x "$bin.tmp" || true
              fi
              # The Linux binary is a Bun single-file executable: it must run
              # pristine (patchelf corrupts it and segfaults). Keep the
              # download untouched as omp.bin and exec it through the Nix
              # glibc loader from a small omp wrapper (NixOS has no /lib).
              if [ -f "$bin.tmp" ]; then
                mv -f "$bin.tmp" "$bin" || true
                chmod +x "$bin" || true
                if [ "$os" = "Linux" ]; then
                  # No heredoc here: nixfmt reindents string bodies, which
                  # would indent the terminator and break the script.
                  printf '%s\n' "#!${pkgs.stdenv.shell}" "exec \"${pkgs.stdenv.cc.bintools.dynamicLinker}\" --library-path \"${
                    lib.makeLibraryPath [
                      pkgs.stdenv.cc.libc
                      (lib.getLib pkgs.stdenv.cc.cc)
                    ]
                  }\" \"$bin\" \"\$@\"" > "$dest" || true
                  chmod +x "$dest" || true
                else
                  mv -f "$bin" "$dest" || true
                fi
              fi
            '';
            deps = [ ];
          };
        })
      ];
    };
  flake.nixosModules.oh-my-pi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ self.nixosModules.omp ];
    };

  # ---------------------------------------------------------------------------
  # Home Manager modules — package + out-of-store symlink + settings + MCP +
  # optional latest-binary fetch.
  # ---------------------------------------------------------------------------
  flake.homeManagerModules.omp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.programs.omp = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Oh My Pi (omp) — prebuilt binary from GitHub releases.";
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
          defaultText = "self.packages.\${system}.omp (pinned GitHub release)";
          description = "OMP package. Set to null to rely solely on useLatestBinary fetch.";
        };
        useLatestBinary = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            When true, also download the latest GitHub release binary to ~/.local/bin/omp
            on each activation (curl -fsSL https://github.com/can1357/oh-my-pi/releases/latest/download/...) for instant auto-update.
            Package itself already auto-updates (--impure). Set false to pin to nix store.
          '';
        };
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "OMP settings written to ~/.omp/agent/config.yml (YAML).";
        };
      };

      options.programs.oh-my-pi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Alias for programs.omp.enable (compat with pre-overlay config).";
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Alias for programs.omp.package.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf config.programs.oh-my-pi.enable { programs.omp.enable = true; })
        (lib.mkIf (config.programs.oh-my-pi.package != null) {
          programs.omp.package = config.programs.oh-my-pi.package;
        })
        # Dendritic default: enable omp, wire ~/.omp out-of-store, and
        # declare current non-secret settings.
        {
          programs.omp.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
          programs.omp.enable = lib.mkDefault true;
          programs.omp.useLatestBinary = lib.mkDefault true;
          programs.omp.settings = {
            modelRoles = {
              # DeepSeek V4.1 Flash: 1M ctx, 384K out, vision, $0.15/$0.60.
              default = "opencode-go/deepseek-flash";
              # GLM-5.3-Flash: cheapest capable tool-use model, $60 cap.
              task = "opencode-go/glm-5.3-flash";
              # DeepSeek V4 Pro: deepest cheap reasoning, 384K out.
              plan = "opencode-go/deepseek-v4-pro";
              # GLM-5.3: flagship tier for long, hard sessions.
              slow = "opencode-go/glm-5.3";
              # MiMo V2.5: cheap enough to review every turn, own $60 cap.
              advisor = "opencode-go/mimo-v2.5";
              smol = "opencode-go/glm-5.3-flash";
              commit = "opencode-go/mimo-v2.5";
              # Qwen3.8 Flash: vision-first build, $30 cap.
              vision = "opencode-go/qwen3.8-flash";
            };
            # Cross-family chains: each hop owns a separate monthly cap, so a
            # cap wall or an outage fails over instead of blocking the turn.
            retry = {
              modelFallback = true;
              fallbackChains = {
                # Also the catch-all chain for roles without their own entry.
                default = [
                  "opencode-go/deepseek-v4-flash"
                  "opencode-go/glm-5.3-flash"
                  "opencode-go/qwen3.8-flash"
                  "opencode-go/minimax-m3"
                ];
                task = [
                  "opencode-go/mimo-v2.5"
                  "opencode-go/deepseek-flash"
                  "opencode-go/qwen3.8-flash"
                ];
                plan = [
                  "opencode-go/glm-5.2"
                  "opencode-go/deepseek-flash"
                ];
                slow = [
                  "opencode-go/qwen3.8-max"
                  "opencode-go/deepseek-v4-pro"
                  "opencode-go/kimi-k3"
                ];
                advisor = [
                  "opencode-go/glm-5.3-flash"
                  "opencode-go/deepseek-flash"
                ];
                smol = [
                  "opencode-go/mimo-v2.5"
                  "opencode-go/deepseek-flash"
                ];
                commit = [
                  "opencode-go/glm-5.3-flash"
                  "opencode-go/deepseek-flash"
                ];
                vision = [
                  "opencode-go/gpt-5.6-luna"
                  "opencode-go/deepseek-v4-flash-vision-exp"
                  "opencode-go/glm-5.3-flash"
                ];
              };
            };
            providers = {
              tinyModel = "lfm2-350m";
              tinyModelDevice = "gpu";
            };
            symbolPreset = "nerd";
            theme.dark = "dark-catppuccin";
            setupVersion = 1;
            hideThinkingBlock = true;
            memory.backend = "off";
            autolearn = {
              enabled = true;
              autoContinue = true;
            };
            bash.autoBackground.enabled = true;
            bashInterceptor.enabled = true;
            shellMinimizer.sourceOutlineLevel = "default";
            github.enabled = true;
            mcp = { };
            task = {
              eager = "default";
              isolation.mode = "auto";
            };
            advisor = {
              enabled = true;
              subagents = true;
              syncBacklog = "5";
            };
            steeringMode = "one-at-a-time";
            compaction.handoffSaveToDisk = true;
            browser.headless = false;
            defaultThinkingLevel = "auto";
            dev.autoqaConsent = "granted";
            includeWorkspaceTree = true;
            features.unexpectedStopDetection = true;
            edit.mode = "hashline";
            lsp.formatOnWrite = true;
            astGrep.enabled = true;
          };

          # Out-of-store symlink: omp mutates ~/.omp constantly (dbs,
          # sessions, logs, model caches). A store symlink would be read-only
          # and break every launch. force=true so rebuilds don't fail on
          # existing ~/.omp.hm-backup collision (HM would otherwise refuse to
          # clobber the backup).
          home.file.".omp" = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/omp/home";
            force = true;
          };
        }
        (lib.mkIf config.programs.omp.enable (
          lib.mkMerge [
            {
              home.packages = lib.optionals (config.programs.omp.package != null) [
                config.programs.omp.package
              ];
            }
            # Write config.yml from settings (YAML) into the out-of-store dir.
            # Upstream's HM module did this via programs.omp.settings activation;
            # we replicate with a direct activation to avoid importing upstream.
            {
              home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run mkdir -p "$HOME/.omp/agent"
                run cat > "$HOME/.omp/agent/config.yml" <<'OMP_EOF'
                ${lib.generators.toYAML { } config.programs.omp.settings}
                OMP_EOF
                run chmod 600 "$HOME/.omp/agent/config.yml"
              '';
            }
            {
              home.activation.ompMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run mkdir -p "$HOME/.omp/agent"
                run cat > "$HOME/.omp/agent/mcp.json" <<'MCP_EOF'
                ${builtins.toJSON {
                  "$schema" =
                    "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
                  mcpServers = {
                    hindsight = {
                      type = "http";
                      url = "http://localhost:8888/mcp";
                    };
                    scrapling = {
                      type = "http";
                      url = "http://127.0.0.1:8000/mcp";
                    };
                    agentwebsearch = {
                      type = "sse";
                      url = "http://127.0.0.1:8902/sse";
                    };
                    agent-browser = {
                      type = "stdio";
                      command = "agent-browser";
                      args = [ "mcp" ];
                    };
                  };
                }}
                MCP_EOF
                run chmod 600 "$HOME/.omp/agent/mcp.json"
              '';
            }
            # Imperative latest-binary fetch (releases/latest/download).
            (lib.mkIf config.programs.omp.useLatestBinary {
              home.activation.ompLatestBinary = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                # Activation PATH is minimal (coreutils present, curl/wget are
                # not) — pin fetchers and friends to the store.
                export PATH="${
                  lib.makeBinPath [
                    pkgs.curl
                    pkgs.wget
                    pkgs.coreutils
                  ]
                }:$PATH"
                run mkdir -p "$HOME/.local/bin"
                # Resolve asset name from uname; glibc build on Linux,
                # shipped pristine behind a loader wrapper (see _omp.pkg.nix:
                # patchelf corrupts this Bun executable and segfaults it).
                asset=""
                os=$(uname -s 2>/dev/null || echo Linux)
                arch=$(uname -m 2>/dev/null || echo x86_64)
                case "$os-$arch" in
                  Linux-x86_64|Linux-x86-64) asset="omp-linux-x64" ;;
                  Linux-aarch64|Linux-arm64) asset="omp-linux-arm64" ;;
                  Darwin-x86_64|Darwin-x86-64) asset="omp-darwin-x64" ;;
                  Darwin-arm64|Darwin-aarch64) asset="omp-darwin-arm64" ;;
                  *) asset="omp-linux-x64" ;;
                esac
                url="https://github.com/can1357/oh-my-pi/releases/latest/download/$asset"
                dest="$HOME/.local/bin/omp"
                bin="$HOME/.local/bin/omp.bin"
                tmp="$bin.tmp"
                # Activation PATH lacks curl/wget — use store absolute paths.
                # Keep failures non-fatal (offline) so activation never breaks.
                downloaded=0
                if run ${pkgs.curl}/bin/curl -fsSL "$url" -o "$tmp"; then
                  downloaded=1
                elif run ${pkgs.wget}/bin/wget -qO "$tmp" "$url"; then
                  downloaded=1
                fi
                if [ "$downloaded" = 1 ] && [ -f "$tmp" ]; then
                  run chmod +x "$tmp"
                  run mv -f "$tmp" "$bin"
                  if [ "$os" = "Linux" ]; then
                    # No heredoc here: nixfmt reindents string bodies, which
                    # would indent the terminator and break the script.
                    printf '%s\n' "#!${pkgs.stdenv.shell}" "exec \"${pkgs.stdenv.cc.bintools.dynamicLinker}\" --library-path \"${
                      lib.makeLibraryPath [
                        pkgs.stdenv.cc.libc
                        (lib.getLib pkgs.stdenv.cc.cc)
                      ]
                    }\" \"$bin\" \"\$@\"" > "$dest" || true
                    run chmod +x "$dest"
                  else
                    run mv -f "$bin" "$dest"
                  fi
                  verboseEcho "omp: fetched latest binary $asset to $bin"
                else
                  verboseEcho "omp: failed to fetch latest binary, keeping existing"
                  rm -f "$tmp" || true
                fi
              '';
            })
          ]
        ))
      ];
    };

  # Compat alias: imports = [ self.homeManagerModules.oh-my-pi ] still works.
  flake.homeManagerModules.oh-my-pi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ self.homeManagerModules.omp ];
    };

  # ---------------------------------------------------------------------------
  # Per-system outputs — binary package + apps.
  # ---------------------------------------------------------------------------
  perSystem =
    { pkgs, ... }:
    let
      ompPkg = pkgs.callPackage ./_omp.pkg.nix { };
    in
    {
      packages.omp = ompPkg;
      packages.oh-my-pi = ompPkg;

      apps.omp = {
        type = "app";
        program = "${ompPkg}/bin/omp";
      };
      apps.oh-my-pi = {
        type = "app";
        program = "${ompPkg}/bin/omp";
      };
    };
}
