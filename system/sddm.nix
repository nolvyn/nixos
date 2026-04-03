# sddm.nix

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
}
