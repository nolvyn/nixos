# gaming.nix
{ config, pkgs, lib, ... }:

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
    prismlauncher
    protonup-qt
  ];

  services.flatpak = {

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "launcher.moe";
        location = "https://gol.launcher.moe/gol.launcher.moe.flatpakrepo";
      }
    ];

    packages = [
      {
        appId = "net.lutris.Lutris";
        origin = "flathub";
      }
      {
        appId = "moe.launcher.an-anime-game-launcher";
        origin = "launcher.moe";
      }
      {
        appId = "moe.launcher.the-honkers-railway-launcher";
        origin = "launcher.moe";
      }
      {
        appId = "moe.launcher.honkers-launcher";
        origin = "launcher.moe";
      }
      {
        appId = "moe.launcher.sleepy-launcher";
        origin = "launcher.moe";
      }
    ];
  };
}
