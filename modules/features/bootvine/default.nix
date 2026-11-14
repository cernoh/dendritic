{ self, inputs, ... }:
{
  flake.nixosModules.bootvine =
    { ... }:
    {
      imports = [ inputs.bootvine.nixosModules.default ];

      services.bootvine.enable = true;
    };
}
