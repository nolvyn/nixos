{ lib, ... }:
{
  den.aspects.ghostty = {
    homeManager =
      { host, pkgs, ... }:
      let
        isDarwin = lib.hasSuffix "darwin" host.system;
      in
      {
        programs.ghostty = {
          enable = true;
          package = if isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
          enableFishIntegration = true;
        };
      };
  };
}
