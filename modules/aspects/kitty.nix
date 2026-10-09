{ lib, ... }:
{
  den.aspects.kitty = {
    homeManager =
      { pkgs, ... }:
      let
        isLinux = pkgs.stdenv.hostPlatform.isLinux;
      in
      {
        programs.kitty = {
          enable = true;
          font = {
            name = "JetBrains Mono Nerd Font";
            size = 12;
          };
          settings = {
            background_opacity = "0.85";
            shell_integration = "no-rc";
          };
          extraConfig = lib.optionalString isLinux "include colors.conf";
        };
      };
  };
}
