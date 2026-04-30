{ config, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../system/gaming.nix
    # ../../system/jellyfin.nix
    ../../system/printing.nix
    # ../../system/searxng.nix
    # ../../system/virtualization.nix
  ];

  environment.systemPackages = with pkgs; [
    # ente-desktop
    # ladybird
    microfetch
    qbittorrent
    # servo
  ];

  machine.isDesktop = true;

  networking.hostName = "WeebMachine";

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;
      ".config/hypr/autostart-extra.conf".source = ../../config/hypr/modules/autostart-wm.conf;
    };
  };
}
