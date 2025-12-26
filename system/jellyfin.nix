# keyboard.nix
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
}
