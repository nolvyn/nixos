{ ... }:
{
  den.aspects.packages = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        anki
        brightnessctl
        celluloid
        claude-code
        dunst
        exiftool
        file
        filen-desktop
        ghostty
        glib
        gzip
        jq
        lynis
        mediainfo
        nautilus
        networkmanagerapplet
        playerctl
        stable.protonvpn-gui
        resources
        ripgrep
        ripunzip
        sherlock
        slack
        spotify
        tree
        unrar
        stable.walker
        wget
      ];
    };
  };
}
