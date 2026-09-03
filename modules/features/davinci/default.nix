{
  moduleWithSystem,
  self,
  ...
}:
{
  flake.nixosModules.davinci = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = with self'.packages; [
        davinci-resolve
      ];
    }
  );
  perSystem =
    { inputs', lib, system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") {
      packages.davinci-resolve = inputs'.davinci.packages.default;
    };
}
