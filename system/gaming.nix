# gaming.nix
{ inputs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    heroic
    lutris
    prismlauncher
    protonplus
    wineWow64Packages.stable # 32 and 64 bit
  ];

  # For more information see https://nixos.wiki/wiki/Steam
  # "SteamDeck=1 %command%", "SteamOS=1 %command%", or "UMU_ID=0 %command%" needed for some games to run properly
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = false; # Sets option to allow login with a gamescope session in display manager
    localNetworkGameTransfers.openFirewall = false;
    remotePlay.openFirewall = false;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
      inputs.moe-gaming.packages.${pkgs.stdenv.hostPlatform.system}.dw-proton-bin
    ];
  };

  programs.honkers-railway-launcher.enable = true;
  programs.sleepy-launcher.enable = true;

  boot.kernelModules = [ "ntsync" ]; # Fix Endfield crashing
}
