{ den, ... }:
{
  den.hosts.aarch64-darwin.Astraeus = {
    hostName = "Astraeus";
    userName = "nolan";
    isLaptop = true;
    users.nolan = { };
  };

  den.aspects.Astraeus = {
    includes = [ den.aspects.determinate ];
  };
}
