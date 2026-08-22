{ ... }:
{
  den.aspects.portableApps = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        exiftool
        file
        filen-desktop
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
