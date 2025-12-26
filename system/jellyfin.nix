# keyboard.nix
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = config.user.name;
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
}
