{ inputs, ... }:
{
  flake-file.inputs = {
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "unstable";
    };
    moe-gaming = {
      url = "github:nolvyn/moe-gaming-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  den.aspects.gaming = {
    nixos =
      { host, pkgs, ... }:
      {
        imports = [
          inputs.aagl.nixosModules.default
          inputs.moe-gaming.nixosModules.default
        ];
        nixpkgs.overlays = [ inputs.moe-gaming.overlays.default ];
        environment.persistence."/persistent".users.${host.userName}.directories = [
          "Games"
          ".cache/mesa_shader_cache"
          ".cache/radv_builtin_shaders"
          ".cache/Proton"
          ".cache/sleepy-launcher"
          ".cache/umu"
          ".cache/umu-protonfixes"
          ".config/heroic"
          ".config/Proton"
          ".local/share/honkers-railway-launcher"
          ".local/share/PrismLauncher"
          ".local/share/sleepy-launcher"
          ".local/share/Steam"
          ".local/share/umu"
          ".local/state/Heroic"
        ];
        environment.systemPackages = with pkgs; [
          unstable.heroic
          prismlauncher
        ];

        # For more information see https://nixos.wiki/wiki/Steam
        # "SteamDeck=1 %command%", "SteamOS=1 %command%", or "UMU_ID=0 %command%" needed for some games to run properly
        programs.steam = {
          enable = true;
          dedicatedServer.openFirewall = false;
          gamescopeSession.enable = false;
          localNetworkGameTransfers.openFirewall = false;
          remotePlay.openFirewall = false;
          extraCompatPackages = with pkgs; [
            proton-ge-bin
          ];
        };

        moe-gaming.dw-proton-bin.enable = true;

        programs.honkers-railway-launcher.enable = true;
        programs.sleepy-launcher.enable = true;

        boot.kernelModules = [ "ntsync" ];
      };
  };
}
