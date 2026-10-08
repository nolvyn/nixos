{ den, inputs, ... }:
{
  den.hosts.aarch64-darwin.Astraeus = {
    hostName = "Astraeus";
    userName = "nolan";
    isLaptop = true;
    users.nolan = { };
  };

  den.aspects.Astraeus = {
    includes = with den.aspects; [
      common
      determinate
      homebrew
      omniwm
      macAppUtil
    ];

    darwin = { host, ... }: {
      networking.computerName = host.hostName;

      programs.mas = {
        enable = true;
        packages = { };
        cleanup = true;
        update = false;
      };
    };

    # Home Manager otherwise inherits nix-darwin's newer package source.
    homeManager = {
      _module.args.pkgsPath = inputs.nixpkgs;
    };
  };
}
