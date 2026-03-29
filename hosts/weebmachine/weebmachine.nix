{ config, pkgs, lib, ... }:

{
  imports = [
    ./weebmachine-hardware.nix
    # ../../system/btrfs.nix
    ../../system/gaming.nix
    # ../../system/jellyfin.nix
    # ../../system/searxng.nix
    # ../../system/virtualization.nix
  ];

  environment.systemPackages = with pkgs; [
    # ente-desktop
    # ladybird
    qbittorrent
    sherlock
  ];

  networking.hostName = "WeebMachine";

  users.users.${config.user.name} = {};

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;
      ".config/hypr/autostart-mn.conf".text = "";
      ".config/hypr/autostart-wm.conf".source = ../../config/hypr/modules/autostart-wm.conf; 
    };
  };
}
