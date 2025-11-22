# flake.nix
{
  inputs = {
    stable = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };

    unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "stable";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "stable";
    };
  };

  outputs = inputs@ { 
    self, 
    stable,
    unstable,
    hjem,
    nix-flatpak,
    quickshell,
    ... 
  }:
  
  let
    lib = stable.lib;
    system = "x86_64-linux";
    
    pkgs = import stable {
      inherit system;
      config.allowUnfree = true;
    };

    u = import unstable {
      inherit system;
      config.allowUnfree = true;
    };

    unstableOverlay = finl: prev: {
      unstable = u;
    };

    commonNixosModules = [
      ./configuration.nix
      ./system/options.nix
      hjem.nixosModules.hjem
      nix-flatpak.nixosModules.nix-flatpak

      { nixpkgs.overlays = [ unstableOverlay ]; }
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
