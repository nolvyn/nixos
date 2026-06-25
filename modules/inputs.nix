{ lib, ... }:

let
  version = "26.05";
in
{
  flake-file.outputs = "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)";

  flake-file.inputs = {
    flake-file.url = lib.mkDefault "github:vic/flake-file";

    nixpkgs.follows = "stable";

    # master.url = "github:nixos/nixpkgs/master";
    # specific.url = "github:nixos/nixpkgs/e0892a72016721b30e65ac2ac3303cbf694dc738";
    unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    warm.url = "github:nixos/nixpkgs/nixos-${version}";
    stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-${version}-chilled/0.1";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";

    den.url = "github:denful/den/latest";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };
  };
}
