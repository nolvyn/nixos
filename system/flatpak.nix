# flatpak.nix
{ config, pkgs, lib, ... }:

{
  services.flatpak = {
    enable = true;
    uninstallUnmanaged = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
