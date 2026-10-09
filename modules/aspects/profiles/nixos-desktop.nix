{ den, ... }:
{
  # Complete current NixOS graphical-machine profile. Keep the storage
  # dependency explicit rather than making the portable base imply it.
  den.aspects.nixosDesktop = {
    includes = with den.aspects; [
      linuxDesktop
      nixosBase
      nixosSecurity
      nixosStorage
    ];
  };
}
