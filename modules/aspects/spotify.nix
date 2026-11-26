{ ... }:
{
  den.aspects.spotify = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".cache/spotify"
        ".config/spotify"
      ];
    };

    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.spotify ];
    };
  };
}
