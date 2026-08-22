{ inputs, ... }:
{
  flake-file.inputs.mac-app-util.url = "github:hraban/mac-app-util";

  den.aspects.macAppUtil = {
    darwin = {
      imports = [ inputs.mac-app-util.darwinModules.default ];
      services.mac-app-util.enable = true;
    };

    homeManager = {
      imports = [ inputs.mac-app-util.homeManagerModules.default ];
      targets.darwin."mac-app-util".enable = true;
    };
  };
}
