{ config, ... }:

let
  hyprDir = "${config.home.homeDirectory}/nixos/config/hypr";
in

{
  home.file = {
    # Core Programs
    ".config/hypr/hyprland.lua".source = config.lib.file.mkOutOfStoreSymlink "${hyprDir}/hyprland.lua";
    ".config/hypr/hyprpaper.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/hyprpaper.conf";
    ".config/hypr/hyprlock.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/hyprlock.conf";

    # Various Modules
    ".config/hypr/modules/animations.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/animations.lua";
    ".config/hypr/modules/autostart.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/autostart.lua";
    ".config/hypr/modules/constants.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/constants.lua";
    ".config/hypr/modules/decorations.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/decorations.lua";
    ".config/hypr/modules/input.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/input.lua";
    ".config/hypr/modules/keybinds.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/keybinds.lua";
    ".config/hypr/modules/monitors.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/monitors.lua";
    ".config/hypr/modules/workspaces.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${hyprDir}/modules/workspaces.lua";
  };
}
