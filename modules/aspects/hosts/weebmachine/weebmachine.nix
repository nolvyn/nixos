{ den, ... }:
{
  den.hosts.x86_64-linux.WeebMachine = {
    users.weeb = { };
  };

  den.aspects.WeebMachine = {
    includes = with den.aspects; [
      nixosBase
      nixosStorage
      nixosSecurity
      linuxDesktop
      workstation
      anki
      printing
      qbittorrent
    ];

    nixos =
      { pkgs, lib, ... }:
      {
        hardware.bluetooth.powerOnBoot = lib.mkForce true;
        environment.systemPackages = with pkgs; [
          unstable.pkgsRocm.blender
          # microfetch
        ];
      };
  };
}
