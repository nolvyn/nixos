{ ... }:
{
  den.aspects.anki = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".local/share/Anki2"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.anki ];
      };
  };
}
