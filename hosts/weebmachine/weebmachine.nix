{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../system/gaming.nix
    ../../system/printing.nix
    ../../system/qbittorrent.nix
  ];

  environment.systemPackages = with pkgs; [
    # ente-desktop
    # ladybird
    microfetch
    # servo
  ];

  machine.isDesktop = true;

  networking.hostName = "WeebMachine";

  hardware.bluetooth.powerOnBoot = lib.mkForce true;

  home-manager.users.${config.user.name} = import ../../home/hosts/weebmachine.nix;
}
