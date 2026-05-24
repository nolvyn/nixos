{ den, ... }:
{
  den.aspects.WeebMachine = {
    nixos =
      { pkgs, lib, ... }:
      {
        hardware.bluetooth.powerOnBoot = lib.mkForce true;
        environment.systemPackages = with pkgs; [ microfetch ];
      };

    includes = [
      den.aspects.common
      den.aspects.gaming
      den.aspects.printing
      den.aspects.qbittorrent
    ];
  };
}
