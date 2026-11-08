{
  description = "Local llama.cpp server that titles pi sessions with Qwen3-1.7B";

  # Pinned to the revision the dendritic host is built from, so this flake
  # resolves against a nixpkgs tree already in the store instead of adding a
  # second one. Bump it together with the top-level flake.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      cuda = system: system == "x86_64-linux";

      # The router's preset section name IS the model id, so this string is what
      # pi lists and what `agents/title-generator.md` must say after
      # `llama.cpp/`. Renaming it renames the model in pi.
      modelId = "Qwen3-1.7B-Q4_K_M";

      # Q4_K_M of unsloth's Qwen3-1.7B-GGUF, pinned to a commit rather than
      # `main` so the hash keeps meaning something. Hash from
      # `nix store prefetch-file --hash-type sha256` on the resolved URL.
      gguf = {
        url = "https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf";
        hash = "sha256-sTmUnFvXSTetjtjIzz2f+x6ZyGbIIyBNxCwNkfoYGJc=";
      };

      # A title request is 4-8 words out of a serialized session that can run to
      # thousands of tokens. 16k is far past the point where more context
      # improves the title, and it costs ~1 GB of KV cache, which the 8 GB card
      # does not notice.
      ctxSize = 16384;

      # pi's llama.cpp provider defaults to this port (DEFAULT_LLAMA_SERVER_URL).
      defaultPort = 8080;

      mkSystem =
        system:
        let
          # `cudaSupport` is a nixpkgs *config* flag, not an argument: with it
          # set, llama-cpp builds the CUDA backend and nixpkgs hands it the
          # matching cudaPackages. Unfree is required for the CUDA
          # redistributables. ASAHI is an Apple-silicon machine with no NVIDIA
          # device, so aarch64 gets the plain CPU build.
          pkgs = import nixpkgs {
            inherit system;
            config = {
              cudaSupport = cuda system;
              allowUnfree = true;
            };
          };

          model = pkgs.fetchurl {
            inherit (gguf) url hash;
            name = "${modelId}.gguf";
          };

          # Router preset, not `--models-dir`: pi only lists a model it can see
          # as loaded, or as an unloaded *preset*. A plain file in a models
          # directory has no source, so it stays invisible in `/model`.
          # `load-on-startup` keeps the model resident — a title job that has to
          # wait for a load on first use would eat its own 15 s timeout.
          #
          # `reasoning = off` is load-bearing, not cosmetic. Qwen3's chat
          # template defaults `enable_thinking` to on, and with thinking on the
          # model spends the whole 512-token budget deliberating and returns an
          # EMPTY content string. Measured: finish_reason "length", 0 characters.
          # Disabling it here holds for every client, even one that sends no
          # chat template kwargs.
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
              # Extra arguments are passed through to llama-server, so
              # `pi-titler --verbose` works when a title comes back wrong.
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
          inherit pkgs serve;
          packages = {
            inherit model;
            # Exposed for `nix run .#llama -- --help` and for checking that the
            # build really carries CUDA (`llama-server --list-devices`).
            llama = pkgs.llama-cpp;
            default = serve;
          };
        };

      systems' = lib.genAttrs systems mkSystem;
    in
    {
      packages = lib.mapAttrs (_: system: system.packages) systems';

      apps = lib.mapAttrs (_: system: {
        default = {
          type = "app";
          program = "${system.serve}/bin/pi-titler";
        };
      }) systems';

      formatter = lib.mapAttrs (_: system: system.pkgs.nixfmt) systems';
    };
}
