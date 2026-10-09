{ lib, ... }:
{
  den.aspects.btop = {
    homeManager =
      { pkgs, ... }:
      let
        isLinux = pkgs.stdenv.hostPlatform.isLinux;
      in
      {
        programs.btop = {
          enable = true;
          settings = {
            theme_background = false;
          }
          // lib.optionalAttrs isLinux {
            color_theme = "matugen";
          };
        };
      };
  };
}
