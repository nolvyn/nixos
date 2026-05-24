{
  inputs,
  lib,
  den,
  ...
}:
let
  stableOverlay = final: prev: {
    stable = import inputs.stable {
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  unstableOverlay = final: prev: {
    unstable = import inputs.unstable {
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  version = "25.11";
in
{
  imports = [
    inputs.den.flakeModule
    inputs.flake-file.flakeModules.default
  ];

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
  ];

  den.default = {
    nixos = {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        stableOverlay
        unstableOverlay
      ];
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      system.stateVersion = version;
    };

    homeManager = {
      home.stateVersion = version;
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        stableOverlay
        unstableOverlay
      ];
    };
  };
}
