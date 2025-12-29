{ config, pkgs, lib, ... }:

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
    qbittorrent
    sherlock
  ];

  networking.hostName = "WeebMachine";

  users.users.${config.user.name} = {};
}
