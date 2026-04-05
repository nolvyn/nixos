# sddm.nix
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    sddm-astronaut
  ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    enableHidpi = true;
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      sddm-astronaut
      kdePackages.qtmultimedia
      kdePackages.qtsvg
    ];
  };
}
