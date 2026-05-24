{ den, ... }:
{
  den.aspects.WeebMachine = {
    includes = with den.aspects; [
      common
      gaming
      printing
      qbittorrent
    ];

    nixos =
      { pkgs, lib, ... }:
      {
        hardware.bluetooth.powerOnBoot = lib.mkForce true;
        environment.systemPackages = with pkgs; [ microfetch ];
      };
  };
}
