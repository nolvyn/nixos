{ inputs, ... }:
{
  flake-file.inputs.android-cli-plugin = {
    url = "github:android/android-cli-plugin";
    flake = false;
  };

  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  den.aspects.ai.provides.general = {
    nixos =
      {
        host,
        pkgs,
        ...
      }:
      {
        nixpkgs.overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];

        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".mcp-auth" ];
        };

        nix.settings = {
          extra-substituters = [ "https://cache.numtide.com" ];
          extra-trusted-public-keys = [
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };
      };

    homeManager =
      {
        lib,
        osConfig,
        ...
      }:
      {
        # NixOS hosts get this overlay from the system pkgs (useGlobalPkgs).
        nixpkgs.overlays = lib.mkIf (!osConfig.home-manager.useGlobalPkgs) [
          inputs.llm-agents.overlays.shared-nixpkgs
        ];

        programs.mcp = {
          enable = true;
          servers = {
            mcp-nixos = {
              command = "uvx";
              args = [ "mcp-nixos" ];
            };
          };
        };
      };
  };
}
