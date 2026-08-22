{ lib, ... }:
{
  den.aspects.btop = {
    homeManager =
      { host, ... }:
      let
        isLinux = lib.hasSuffix "linux" host.system;
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
