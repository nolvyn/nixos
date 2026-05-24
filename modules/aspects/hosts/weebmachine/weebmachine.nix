{ den, ... }:
{
  den.aspects.WeebMachine = {
    nixos =
      { pkgs, lib, ... }:
      {
        hardware.bluetooth.powerOnBoot = lib.mkForce true;
        environment.systemPackages = with pkgs; [ microfetch ];
      };

    includes = with den.aspects; [
      common
      gaming
      printing
      qbittorrent
    ];
  };
}
