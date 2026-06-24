{ lib, ... }:

let
  version = "26.05";
in
{
  flake-file.outputs = "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)";

  flake-file.inputs = {
    flake-file.url = lib.mkDefault "github:vic/flake-file";

    nixpkgs.follows = "stable";
    specific.url = "github:nixos/nixpkgs/e0892a72016721b30e65ac2ac3303cbf694dc738";
    stable.url = "github:nixos/nixpkgs/nixos-${version}";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

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
