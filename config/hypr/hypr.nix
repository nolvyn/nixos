# hypr.nix
{
  config,
  inputs,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    withUWSM = false;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
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
      ".config/hypr/hyprland.lua".source = ./hyprland.lua;
      ".config/hypr/hyprpaper.conf".source = ./hyprpaper.conf;
      ".config/hypr/hyprlock.conf".source = ./hyprlock.conf;

      ".config/hypr/modules/animations.lua".source = ./modules/animations.lua;
      ".config/hypr/modules/autostart.lua".source = ./modules/autostart.lua;
      ".config/hypr/modules/constants.lua".source = ./modules/constants.lua;
      ".config/hypr/modules/decorations.lua".source = ./modules/decorations.lua;
      ".config/hypr/modules/input.lua".source = ./modules/input.lua;
      ".config/hypr/modules/keybinds.lua".source = ./modules/keybinds.lua;
      ".config/hypr/modules/monitors.lua".source = ./modules/monitors.lua;
      ".config/hypr/modules/workspaces.lua".source = ./modules/workspaces.lua;
    };
  };
}
