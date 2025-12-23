# theme.nix
{ config, pkgs, lib, ... }:

{
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      { settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme    = "Adwaita-dark";
            icon-theme   = "Adwaita";
          };
        };
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    gnome-themes-extra # Extra GTK themes
  ];
}
