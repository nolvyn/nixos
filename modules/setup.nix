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
in
{
  imports = [ inputs.den.flakeModule ];

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
  ];

  den.default.nixos = {
    imports = [
      inputs.aagl.nixosModules.default
      inputs.agenix.nixosModules.default

      inputs.impermanence.nixosModules.impermanence
      inputs.moe-gaming.nixosModules.default
      inputs.stevenblack-hosts.nixosModule
    ];
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [
      stableOverlay
      unstableOverlay
      inputs.moe-gaming.overlays.default
      inputs.nix-vscode-extensions.overlays.default
    ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    system.stateVersion = "25.11";
  };

  den.default.homeManager = {
    home.stateVersion = "25.11";
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [
      stableOverlay
      unstableOverlay
      inputs.nix-vscode-extensions.overlays.default
    ];
  };
}
