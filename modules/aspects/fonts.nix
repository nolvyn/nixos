# fonts.nix

# For more information see https://wiki.nixos.org/wiki/Fonts
{ ... }:
{
  den.aspects.fonts = {
    nixos = { pkgs, ... }: {
      fonts = {
        enableDefaultPackages = false;
        packages = with pkgs; [
          corefonts # Microsoft fonts (Arial, Times New Roman, etc)
          dejavu_fonts
          inter
          nerd-fonts.jetbrains-mono
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          noto-fonts-color-emoji
        ];
        fontconfig.defaultFonts = {
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
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    darwin = { pkgs, ... }: {
      fonts.packages = with pkgs; [
        corefonts
        dejavu_fonts
        inter
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];
    };
  };
}
