{ config, pkgs, lib, ... }:

{
  # For more information see https://nixos.wiki/wiki/Steam
  # "SteamDeck=1 %command%", "SteamOS=1 %command%", or "UMU_ID=0 %command%" needed for some games to run properly
  programs.steam = {
    enable = true;
    
    gamescopeSession.enable = false; # Sets option to login with a gamescope session in display manager
    dedicatedServer.openFirewall = false; # Whether to open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = false; # Whether to open ports in the firewall for Steam Local Network Game Transfers
    remotePlay.openFirewall = false; # Whether to open ports in the firewall for Steam Remote Play
    
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  environment.systemPackages = with pkgs; [
    # lutris # Game Launcher
    heroic # Game Launcher for Epic, GOG, and more
    prismlauncher # Game Launcher for Minecraft
    protonup-qt # GUI for Managing Proton Versions
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
        appId = "com.usebottles.bottles";
        origin = "flathub";
      }
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
