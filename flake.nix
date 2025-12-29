# flake.nix
{
  inputs = {
    stable = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs = inputs@ { 
    self, 
    stable,
    unstable,
    hjem,
    nix-flatpak,
    nix-vscode-extensions,
    ... 
  }:
  
  let
    lib = unstable.lib;
    system = "x86_64-linux";
    
    pkgs = import unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.nix-vscode-extensions.overlays.default
      ];
    };

    s = import unstable {
      inherit system;
      config.allowUnfree = true;
    };

    stableOverlay = finl: prev: {
      stable = s;
    };

    commonNixosModules = [
      ./configuration.nix
      ./system/options.nix
      hjem.nixosModules.hjem
      nix-flatpak.nixosModules.nix-flatpak

      { 
        nixpkgs.overlays = [ 
          stableOverlay
          inputs.nix-vscode-extensions.overlays.default
        ];
      }
    ];
  in

  {
    nixosConfigurations = {
      WeebMachine = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ 
          ./hosts/weebmachine/weebmachine.nix
        ] ++ commonNixosModules;
      };

      MoeNote = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ 
          ./hosts/moenote/moenote.nix
        ] ++ commonNixosModules;
      };
    };
  };
}
