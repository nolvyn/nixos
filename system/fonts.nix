# fonts.nix
{ pkgs, ... }:

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
      noto-fonts-color-emoji
      dejavu_fonts
      corefonts # Microsoft fonts (Arial, Times New Roman, etc)
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
        emoji = [
          "Noto Color Emoji"
        ];
      };
    };
  };
}
