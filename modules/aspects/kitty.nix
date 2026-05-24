{ ... }:
{
  den.aspects.kitty = {
    homeManager = {
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
        extraConfig = "include colors.conf";
      };
    };
  };
}
