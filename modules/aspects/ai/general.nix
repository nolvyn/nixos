{ inputs, ... }:
{
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  den.aspects.ai.provides.general = {
    nixos =
      { host, pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];

        environment.systemPackages = [
          # pkgs.llm-agents.grok
        ];

        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".mcp-auth"
        ];

        nix.settings = {
          extra-substituters = [ "https://cache.numtide.com" ];
          extra-trusted-public-keys = [
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };
      };

    homeManager =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];

        programs.mcp = {
          enable = true;
          servers = {
            context7 = {
              command = "npx";
              args = [
                "-y"
                "@upstash/context7-mcp"
              ];
            };
            mcp-nixos = {
              command = "uvx";
              args = [ "mcp-nixos" ];
            };
          };
        };
      };
  };
}
