# theme.nix
{ config, pkgs, ... }:

{
  # Most matugen templates are stolen from https://github.com/InioX/matugen-themes

  environment.systemPackages = with pkgs; [
    bibata-cursors
    gnome-themes-extra
    matugen
  ];

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "Adwaita-dark";
            icon-theme = "Adwaita";
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

  hjem.users.${config.user.name} = {
    files = {
      ".config/matugen/config.toml".source = ../config/matugen/config.toml;
    };
  };
}
