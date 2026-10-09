{ ... }:
{
  den.aspects.ghostty = {
    homeManager =
      { pkgs, ... }:
      let
        isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
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
