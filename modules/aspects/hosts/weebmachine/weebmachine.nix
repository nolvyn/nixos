{ den, ... }:
{
  den.hosts.x86_64-linux.WeebMachine = {
    isDesktop = true;
    users.weeb = { };
  };

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
