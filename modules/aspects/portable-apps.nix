{ ... }:
{
  den.aspects.portableApps = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        exiftool
        file
        unstable.filen-desktop
        gzip
        jq
        mediainfo
        ripgrep
        ripunzip
        sherlock
        slack
        spotify
        tree
        unrar
        wget
      ];
    };
  };
}
