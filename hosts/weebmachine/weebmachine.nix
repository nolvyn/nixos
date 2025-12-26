{ config, pkgs, lib, ... }:

{
  imports = [
    ./weebmachine-hardware.nix
    ../../system/gaming.nix
    ../../system/jellyfin.nix
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

  # DO NOT CHANGE **YOUR** DEFAULT VALUE HERE UNLESS YOU KNOW WHAT YOU ARE DOING 
  # For more information see https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
