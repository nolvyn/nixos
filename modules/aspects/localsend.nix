{ ... }:
{
  den.aspects.localsend = {
    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.localsend ];
    };

    nixos = { host, ... }: {
      programs.localsend = {
        enable = true;
        openFirewall = true;
      };

      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".local/share/org.localsend.localsend_app"
      ];
    };
  };
}
