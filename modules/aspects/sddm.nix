{ ... }:
{
  den.aspects.sddm = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        sddm-astronaut
      ];

      services.displayManager.defaultSession = "hyprland";

      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        wayland.compositor = "kwin";
        enableHidpi = true;
        theme = "sddm-astronaut-theme";
        extraPackages = with pkgs; [
          bibata-cursors
          kdePackages.qtmultimedia
          kdePackages.qtsvg
          sddm-astronaut
        ];
        settings = {
          Theme = {
            CursorTheme = "Bibata-Modern-Ice";
            CursorSize = 24;
          };
        };
      };
    };
  };
}
