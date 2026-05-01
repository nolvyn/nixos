{ config, pkgs, ... }:

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

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/autostart-extra.conf".source = ../../config/hypr/modules/autostart-wm.conf;
    };
  };
}
