# hypr.nix
{ config, pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # withUWSM = true;
  };
  
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    hyprpaper
    hyprshot
    hyprsunset
  ];

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hyprland.conf".source = ./hyprland.conf;
      ".config/hypr/hyprpaper.conf".source = ./hyprpaper.conf;
      ".config/hypr/hyprlock.conf".source = ./hyprlock.conf;

      ".config/hypr/keybinds.conf".source = ./modules/keybinds.conf;
      ".config/hypr/monitors.conf".source = ./modules/monitors.conf;
      ".config/hypr/autostart.conf".source = ./modules/autostart.conf;
      ".config/hypr/input.conf".source = ./modules/input.conf;
      ".config/hypr/workspaces.conf".source = ./modules/workspaces.conf;
      ".config/hypr/constants.conf".source = ./modules/constants.conf;
    };
  };
}
