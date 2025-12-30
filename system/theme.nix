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

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";
  };

  environment.systemPackages = with pkgs; [
    gnome-themes-extra
    bibata-cursors
  ];
}
