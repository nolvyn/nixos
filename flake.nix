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

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "unstable";
    };

    stevenblack-hosts = {
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs = inputs@{
    self,
    unstable,
    aagl,
    agenix,
    disko,
    hjem,
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
      ./system/options.nix
      aagl.nixosModules.default
      agenix.nixosModules.default
      disko.nixosModules.disko
      hjem.nixosModules.hjem
      stevenblack-hosts.nixosModule
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
