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

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "unstable";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "unstable";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "unstable";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "unstable";
    };

    moe-gaming = {
      url = "github:nolvyn/moe-gaming-nix";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "unstable";
    };

    stevenblack-hosts = {
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs =
    inputs@{
      self,
      unstable,
      aagl,
      agenix,
      disko,
      hjem,
      impermanence,
      moe-gaming,
      nix-vscode-extensions,
      stevenblack-hosts,
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
        aagl.nixosModules.default
        agenix.nixosModules.default
        disko.nixosModules.disko
        hjem.nixosModules.hjem
        impermanence.nixosModules.impermanence
        moe-gaming.nixosModules.default
        stevenblack-hosts.nixosModule
        {
          nixpkgs.overlays = [
            stableOverlay
            moe-gaming.overlays.default
            nix-vscode-extensions.overlays.default
          ];
          nixpkgs.config.allowUnfree = true;
        }
      ];

      mkSystem =
        hostModule:
        lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [ hostModule ] ++ commonNixosModules;
        };
    in

    {
      nixosConfigurations = {
        WeebMachine = mkSystem ./hosts/weebmachine/weebmachine.nix;
        MoeNote = mkSystem ./hosts/moenote/moenote.nix;
      };
    };
}
