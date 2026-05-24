# keyboard.nix

{ ... }:
{
  den.aspects.keyboard = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/fcitx"
        ".config/fcitx5"
        ".config/mozc"
      ];

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "us";
        variant = "";
      };

      i18n.inputMethod = {
        type = "fcitx5";
        enable = true;
        fcitx5 = {
          waylandFrontend = true;
          addons = with pkgs; [
            fcitx5-mozc # Japanese
            fcitx5-gtk
          ];
        };
      };
    };
  };
}
