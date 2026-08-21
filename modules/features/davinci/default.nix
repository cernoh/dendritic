{
  moduleWithSystem,
  self,
  ...
}: {
  flake.nixosModules.davinci = moduleWithSystem ({self', ...}: {
    environment.systemPackages = with self'.packages; [
      davinci-resolve
    ];
  });
  perSystem = {inputs', ...}: {
    packages.davinci-resolve = inputs'.davinci.packages.default;
  };
}
