{ inputs, ... }:
{
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  den.aspects.ai.provides.general = {
    nixos =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.llm-agents.overlays.default ];

        environment.systemPackages = [ pkgs.llm-agents.grok ];

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
        nixpkgs.overlays = [ inputs.llm-agents.overlays.default ];
      };
  };
}
