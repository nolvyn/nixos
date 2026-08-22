{ den, ... }:
{
  den.hosts.aarch64-darwin.Astraeus = {
    hostName = "Astraeus";
    userName = "nolan";
    isLaptop = true;
    users.nolan = { };
  };

  den.aspects.Astraeus = {
    includes = with den.aspects; [
      determinate
      fish
      git
      dev
    ];

    darwin =
      { host, pkgs, ... }:
      {
        networking.computerName = host.hostName;

        # Den v0.18 sets the login shell but predates this Darwin integration.
        environment.shells = [ pkgs.fish ];
      };
  };
}
