# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    den.url = "github:denful/den/latest";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
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
      inputs.nixpkgs.follows = "unstable";
    };
    impermanence.url = "github:nix-community/impermanence";
    import-tree.url = "github:denful/import-tree";
    llm-agents.url = "github:numtide/llm-agents.nix";
    moe-gaming = {
      url = "github:nolvyn/moe-gaming-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.follows = "stable";
    openai-plugins = {
      url = "github:openai/plugins";
      flake = false;
    };
    stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1";
    stevenblack-hosts.url = "github:StevenBlack/hosts";
    unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    warm.url = "github:nixos/nixpkgs/nixos-26.05";
  };
}
