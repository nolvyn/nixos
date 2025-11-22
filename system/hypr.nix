# hypr.nix
{ config, pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
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
      ".config/hypr/hyprland.conf".source = ../config/hypr/hyprland.conf;
      ".config/hypr/hyprpaper.conf".source = ../config/hypr/hyprpaper.conf;
      ".config/hypr/hyprlock.conf".source = ../config/hypr/hyprlock.conf;

      ".config/hypr/keybinds.conf".source = ../config/hypr/modules/keybinds.conf;
      ".config/hypr/monitors.conf".source = ../config/hypr/modules/monitors.conf; 
    };
  };
}
