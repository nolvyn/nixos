{ config, pkgs, lib, ... }:

# For more information see https://wiki.nixos.org/wiki/Fonts
{
  fonts = {
    enableDefaultPackages = false;
    packages = with pkgs; [
        inter
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-emoji
        dejavu_fonts
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [ 
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono"
          "DejaVu Sans Mono"
        ];
        sansSerif = [
          "Inter"
          "Noto Sans"
          "DejaVu Sans"
        ];
        serif = [
          "Noto Serif"
          "DejaVu Serif" 
        ];
      };
    };
  };
}
