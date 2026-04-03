{
  inputs = {
    stable = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "unstable";
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

  outputs = inputs@{ 
    self, 
    unstable,
    aagl,
    hjem,
    nix-flatpak,
    nix-vscode-extensions,
    ... 
  }:

  let
    lib = unstable.lib;

    stableOverlay = final: prev: {
      stable = import inputs.stable {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    };

    commonNixosModules = [
      ./configuration.nix
      ./system/options.nix
      aagl.nixosModules.default
      hjem.nixosModules.hjem
      nix-flatpak.nixosModules.nix-flatpak
      {
        nixpkgs.overlays = [
          stableOverlay
          nix-vscode-extensions.overlays.default
        ];
        nixpkgs.config.allowUnfree = true;
      }
    ];
  in

  {
    nixosConfigurations = {
      WeebMachine = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/weebmachine/weebmachine.nix
        ] ++ commonNixosModules;
      };

      MoeNote = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/moenote/moenote.nix
        ] ++ commonNixosModules;
      };
    };
  };
}
