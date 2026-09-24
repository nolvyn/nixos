{ den, inputs, ... }:
{
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli/nix-homebrew";

  den.aspects.homebrew = {
    darwin =
      { host, ... }:
      {
        imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

        nix-homebrew = {
          enable = true;
          user = host.userName;
        };

        homebrew = {
          enable = true;
          casks = [ "protonvpn" ];
          global.autoUpdate = false;
          onActivation.cleanup = "uninstall";
        };
      };
  };
}
