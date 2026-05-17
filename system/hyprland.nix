{ pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = false;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    hyprpaper
    hyprshot
    hyprsunset
  ];
}
