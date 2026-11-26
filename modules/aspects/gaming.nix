{ inputs, ... }:
{
  flake-file.inputs = {
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
          inputs.moe-gaming.nixosModules.default
        ];
        nixpkgs.overlays = [ inputs.moe-gaming.overlays.default ];
        environment.persistence."/persistent".users.${host.userName}.directories = [
          "Games"
          ".cache/mesa_shader_cache"
          ".cache/radv_builtin_shaders"
          ".cache/umu"
          ".cache/umu-protonfixes"
          ".config/heroic"
          ".local/share/PrismLauncher"
          ".local/share/Steam"
          ".local/share/umu"
          ".local/state/Heroic"
        ];
        environment.systemPackages = with pkgs; [
          # warm carries the newer Electron; the Heroic version is the same.
          warm.heroic
          protonplus
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

        moe-gaming.proton.enable = true;

        boot.kernelModules = [ "ntsync" ];
      };

    darwin = {
      homebrew = {
        taps = [ "notprotonnot/notproton" ];
        casks = [
          "crossover"
          "heroic"
          "notprotonnot/notproton/notproton"
          "steam"
        ];
      };

      programs.mas.packages = {
        "Wuthering Waves" = 6475033368;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.prismlauncher
        ];
      };
  };
}
