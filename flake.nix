# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    den.url = "github:denful/den/latest";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland/v0.55.2";
    impermanence.url = "github:nix-community/impermanence";
    import-tree.url = "github:denful/import-tree";
    moe-gaming = {
      url = "github:nolvyn/moe-gaming-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.follows = "specific";
    specific.url = "github:nixos/nixpkgs/e0892a72016721b30e65ac2ac3303cbf694dc738";
    stable.url = "github:nixos/nixpkgs/nixos-25.11";
    stevenblack-hosts.url = "github:StevenBlack/hosts";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };
}
