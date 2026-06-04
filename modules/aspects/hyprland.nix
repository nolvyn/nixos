{ inputs, lib, ... }:
{
  flake-file.inputs.hyprland.url = "github:hyprwm/Hyprland/v0.55.2";

  den.aspects.hyprland = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/hypr"
      ];

      security.wrappers.Hyprland.capabilities = lib.mkForce "";

      programs.hyprland = {
        enable = true;
        withUWSM = false;
        xwayland.enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      environment.systemPackages = with pkgs; [
        hypridle
        hyprlock
        hyprpaper
        hyprshot
        hyprsunset
      ];
    };

    homeManager = { host, config, ... }: {
      home.file = {
        ".config/hypr/hyprland.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/hyprland.lua";
        ".config/hypr/hyprpaper.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/hyprpaper.conf";
        ".config/hypr/hyprlock.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/hyprlock.conf";
        ".config/hypr/modules/animations.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/animations.lua";
        ".config/hypr/modules/autostart.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/autostart.lua";
        ".config/hypr/modules/constants.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/constants.lua";
        ".config/hypr/modules/decorations.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/decorations.lua";
        ".config/hypr/modules/input.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/input.lua";
        ".config/hypr/modules/keybinds.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/keybinds.lua";
        ".config/hypr/modules/monitors.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/monitors.lua";
        ".config/hypr/modules/workspaces.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/modules/workspaces.lua";
      };
    };
  };
}
