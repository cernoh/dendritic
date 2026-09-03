# Oh My Pi (omp) feature — overlay-based packaging from upstream.
#
# Replaces the former `cernoh/omp-flake` binary wrapper. Upstream
# `can1357/oh-my-pi` is already a full Nix flake with package, overlay,
# homeManagerModules, nixosModules, devShells and checks. This module
# consumes it directly via the `oh-my-pi` input and adds dendritic
# integration:
#
# - Exposes `overlays.omp` (= upstream `overlays.default`) so consumers
#   can add `omp` to any nixpkgs instance with tooling intact.
# - Re-exports `packages.omp` / `apps.omp` per system from upstream.
# - Wraps upstream's `homeManagerModules` (`programs.omp`) with the
#   out-of-store `~/.omp` symlink (same pattern as home-manager-v3:
#   tracked config lives in ./home, runtime state — dbs, sessions, logs —
#   is written live into this checkout). The symlink target is the
#   feature's `home/` directory inside THIS repo.
# - Keeps a `programs.oh-my-pi` alias for backward compatibility with
#   existing local imports, mapping to `programs.omp`.
# - Declares current non-secret settings (from home/agent/config.yml and
#   home/agent/mcp.json, 2026-09-03) via `programs.omp.settings` and
#   `home.activation.ompMcp` — no API keys/tokens in Nix; provide
#   secrets via env / sops-nix / credential store.
#
# Opt in:
#   imports = [ self.homeManagerModules.omp ];
# then either `programs.omp.enable = true` or the compat `programs.oh-my-pi.enable`.
{ inputs, ... }:
{
  # ---------------------------------------------------------------------------
  # Overlay: turn oh-my-pi source into a nixpkgs package with tooling.
  # Upstream's overlay is `final: prev: { omp = self.packages.<system>.default; }`
  # — building from source with Rust + Bun, not a prebuilt binary fetch.
  # Dendritic re-exports it as `overlays.omp` and `overlays.default`.
  # ---------------------------------------------------------------------------
  flake.overlays.omp = inputs.oh-my-pi.overlays.default;
  flake.overlays.default = inputs.oh-my-pi.overlays.default;

  # ---------------------------------------------------------------------------
  # NixOS / Home Manager modules — re-export upstream and wrap HM with
  # dendritic's out-of-store symlink + alias.
  # ---------------------------------------------------------------------------
  flake.nixosModules.omp = inputs.oh-my-pi.nixosModules.default;
  flake.nixosModules.oh-my-pi = inputs.oh-my-pi.nixosModules.default;

  flake.homeManagerModules.omp =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.oh-my-pi.homeManagerModules.default ];

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
        # Alias: programs.oh-my-pi -> programs.omp when the old name is used.
        (lib.mkIf config.programs.oh-my-pi.enable { programs.omp.enable = true; })
        (lib.mkIf (config.programs.oh-my-pi.package != null) {
          programs.omp.package = config.programs.oh-my-pi.package;
        })
        # Dendritic default: enable omp, wire ~/.omp out-of-store, and
        # declare current non-secret settings (migrated from
        # modules/features/omp/home/agent/config.yml, 2026-09-03).
        # Secrets (provider API keys, tokens) are intentionally NOT in Nix:
        # provide them via env (e.g. ANTHROPIC_API_KEY), sops-nix, or
        # `omp`'s own credential store. The file at
        # ~/.omp/agent/config.yml is still written by HM's activation
        # (install -m 600) into the out-of-store dir, so runtime rewrites
        # work, but declared values win on next switch.
        {
          programs.omp.enable = lib.mkDefault true;

          programs.omp.settings = {
            modelRoles = {
              default = "opencode-go/deepseek-v4-flash";
              task = "opencode-go/deepseek-v4-flash";
              plan = "opencode-go/deepseek-v4-flash";
              slow = "opencode-go/deepseek-v4-flash";
              advisor = "opencode-go/deepseek-v4-flash";
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

          # Declarative mcp.json (no secrets). Upstream HM module only
          # handles config.yml; mcp.json is managed here via activation
          # into the same out-of-store dir. Secrets (tokens, keys) would
          # be injected via sops-nix/env, not Nix.
          home.activation.ompMcp = {
            before = [ ];
            after = [ "writeBoundary" ];
            data = ''
              run mkdir -p "$HOME/.omp/agent"
              run cat > "$HOME/.omp/agent/mcp.json" <<'MCP_EOF'
              ${builtins.toJSON {
                "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
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
          };

          # Out-of-store symlink: omp mutates ~/.omp constantly (dbs,
          # sessions, logs, model caches). A store symlink would be read-only
          # and break every launch. Same mechanism as home-manager-v3.
          # HM's `programs.omp.settings` activation writes config.yml
          # (install -m 600) *inside* this dir, so the file in the repo
          # checkout will be overwritten on each switch — that is expected.
          # To avoid a dirty git state, config.yml should be untracked
          # (see home/.gitignore) once declarative is adopted.
          home.file.".omp".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/omp/home";
        }
      ];
    };

  # Compat alias: imports = [ self.homeManagerModules.oh-my-pi ] still works
  # with the same out-of-store symlink and declarative settings.
  flake.homeManagerModules.oh-my-pi =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.oh-my-pi.homeManagerModules.default ];
      config = {
        programs.omp.enable = lib.mkDefault true;
        programs.omp.settings = {
          modelRoles = {
            default = "opencode-go/deepseek-v4-flash";
            task = "opencode-go/deepseek-v4-flash";
            plan = "opencode-go/deepseek-v4-flash";
            slow = "opencode-go/deepseek-v4-flash";
            advisor = "opencode-go/deepseek-v4-flash";
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
        home.activation.ompMcp = {
          before = [ ];
          after = [ "writeBoundary" ];
          data = ''
            run mkdir -p "$HOME/.omp/agent"
            run cat > "$HOME/.omp/agent/mcp.json" <<'MCP_EOF'
            ${builtins.toJSON {
              "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
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
        };
        home.file.".omp".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/omp/home";
      };
    };

  # ---------------------------------------------------------------------------
  # Per-system outputs — package, app, devShell.
  # These front the upstream flake so dendritic IS a nix flake with tooling
  # for oh-my-pi, without consumers needing to add a second input.
  # ---------------------------------------------------------------------------
  perSystem =
    { inputs', ... }:
    {
      packages.omp = inputs'.oh-my-pi.packages.default;
      packages.oh-my-pi = inputs'.oh-my-pi.packages.default;

      apps.omp = inputs'.oh-my-pi.apps.default;
      apps.oh-my-pi = inputs'.oh-my-pi.apps.default;

      # Tooling: `nix develop .#omp` fronts upstream's devShell (Rust
      # toolchain + Bun + bun2nix). The shell is defined in upstream
      # nix/dev-shell.nix.
      devShells.omp = inputs'.oh-my-pi.devShells.default;
    };
}
