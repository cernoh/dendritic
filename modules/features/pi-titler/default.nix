# pi-titler — local llama.cpp server that titles pi sessions with Qwen3-1.7B.
#
# Ported from the standalone `pi-titler/` flake into a dendritic feature so
# NIXPC builds it as part of the system. Exposes `packages.pi-titler`,
# `apps.pi-titler`, `flake.nixosModules.pi-titler` (adds the package to
# `environment.systemPackages`), and `flake.homeManagerModules.pi-titler`
# (runs it as a user service so it is resident whenever pi-bolt is used).
{ self, inputs, moduleWithSystem, ... }:
let
  modelId = "Qwen3-1.7B-Q4_K_M";
  ggufUrl = "https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf";
  ggufHash = "sha256-sTmUnFvXSTetjtjIzz2f+x6ZyGbIIyBNxCwNkfoYGJc=";
  ctxSize = 16384;
  defaultPort = 8080;
in
{
  perSystem =
    { system, ... }:
    let
      cuda = system == "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          cudaSupport = cuda;
          allowUnfree = true;
        };
      };
      model = pkgs.fetchurl {
        url = ggufUrl;
        hash = ggufHash;
        name = "${modelId}.gguf";
      };
      preset = pkgs.writeText "pi-titler-preset.ini" ''
        version = 1

        [${modelId}]
        model = ${model}
        load-on-startup = true
        jinja = true
        reasoning = off
        n-gpu-layers = 999
        ctx-size = ${toString ctxSize}
      '';
      serve = pkgs.writeShellApplication {
        name = "pi-titler";
        text = ''
          exec ${pkgs.llama-cpp}/bin/llama-server \
            --models-preset ${preset} \
            --host 127.0.0.1 \
            --port "''${PI_TITLER_PORT:-${toString defaultPort}}" \
            --parallel 1 \
            --no-webui \
            "$@"
        '';
      };
    in
    {
      packages.pi-titler = serve;
      apps.pi-titler = {
        type = "app";
        program = "${serve}/bin/pi-titler";
      };
    };

  flake.homeManagerModules.pi-titler = moduleWithSystem (
    { self', ... }:
    { config, lib, pkgs, ... }:
    let
      pi-titler = lib.getExe self'.packages.pi-titler;
    in
    {
      systemd.user.services.pi-titler = {
        Unit = {
          Description = "pi-titler: local llama.cpp server for pi session titles";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = pi-titler;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
  );

  flake.nixosModules.pi-titler =
    { pkgs, ... }:
    {
      config = {
        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.pi-titler ];
        home-manager.sharedModules = [ self.homeManagerModules.pi-titler ];
      };
    };
}