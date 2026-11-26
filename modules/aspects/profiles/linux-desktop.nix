{ den, ... }:
{
  # Reusable on NixOS and standalone Linux Home Manager. NixOS needs a storage profile because
  # several desktop aspects declare persistence under /persistent.
  den.aspects.linuxDesktop = {
    includes = with den.aspects; [
      audio
      blender
      bluetooth
      file
      fonts
      hyprland
      keyboard
      rofi
      sddm
      theme
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          brightnessctl
          dunst
          glib
          networkmanagerapplet
          playerctl
          resources
        ];
      };
  };
}
