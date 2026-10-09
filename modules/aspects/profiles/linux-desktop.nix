{ den, ... }:
{
  # Linux desktop configuration can be reused by NixOS or standalone Linux
  # Home Manager. Its NixOS projection needs a storage profile because several
  # of the existing desktop aspects declare persistence under /persistent.
  den.aspects.linuxDesktop = {
    includes = with den.aspects; [
      audio
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
