# gaming.nix
{ config, pkgs, lib, ... }:

let
  gameLibraryPath = "/home/weeb/Games";
  vnLibraryPath = "/home/weeb/vns";

  animeLauncherOverrides = {
    Context = {
      shared = [ "network" "ipc" ];
      sockets = [ "x11" "wayland" "pulseaudio" ];
      devices = [ "all" ];
      filesystems = [
        "!/media"
        "!/mnt"
        "!/run/media"
      ];
    };
  };
in

{
  # For more information see https://nixos.wiki/wiki/Steam
  # "SteamDeck=1 %command%", "SteamOS=1 %command%", or "UMU_ID=0 %command%" needed for some games to run properly
  programs.steam = {
    enable = true;

    gamescopeSession.enable = false; # Sets option to allow login with a gamescope session in display manager
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
    remotePlay.openFirewall = false;
    
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  environment.systemPackages = with pkgs; [
    heroic
    lutris
    prismlauncher
    protonplus
    wineWowPackages.stable # 32 and 64 bit
  ];

  services.flatpak = {
    packages = [
      {
        appId = "moe.launcher.an-anime-game-launcher";
        origin = "flathub";
      }
      {
        appId = "moe.launcher.the-honkers-railway-launcher";
        origin = "flathub";
      }
      {
        appId = "moe.launcher.honkers-launcher";
        origin = "flathub";
      }
      {
        appId = "moe.launcher.sleepy-launcher";
        origin = "flathub";
      }
    ];

    overrides = {
      "moe.launcher.an-anime-game-launcher" = animeLauncherOverrides;
      "moe.launcher.the-honkers-railway-launcher" = animeLauncherOverrides;
      "moe.launcher.honkers-launcher" = animeLauncherOverrides;
      "moe.launcher.sleepy-launcher" = animeLauncherOverrides;
    };
  };
}
