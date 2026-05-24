# theme.nix

# Most matugen templates are stolen from https://github.com/InioX/matugen-themes
{ ... }:
{
  den.aspects.theme = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/dconf"
        ".config/gtk-3.0"
        ".config/gtk-4.0"
      ];

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
    };
  };
}
