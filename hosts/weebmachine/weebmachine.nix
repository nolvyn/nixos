{ config, pkgs, ... }:

{
  imports = [
    ./weebmachine-hardware.nix
    ../../system/gaming.nix
    # ../../system/jellyfin.nix
    # ../../system/searxng.nix
    # ../../system/virtualization.nix
  ];

  environment.systemPackages = with pkgs; [
    # ente-desktop
    # ladybird
    microfetch
    qbittorrent
    # servo
    # sherlock
  ];

  networking = {
    hostName = "WeebMachine";
    networkmanager.settings.connectivity.enabled = false; # Speed up boot time
  };

  users.users.${config.user.name} = { };

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;

      ".config/hypr/autostart-mn.conf".text = "";
      ".config/hypr/autostart-wm.conf".source = ../../config/hypr/modules/autostart-wm.conf;

      "torrents/.ini".text = "";
    };
  };
}
