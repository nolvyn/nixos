{ den, inputs, ... }:
{
  flake-file.inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

  den.aspects.determinate = {
    darwin = {
      imports = [ inputs.determinate.darwinModules.default ];
      determinateNix.enable = true;
    };
  };
}
