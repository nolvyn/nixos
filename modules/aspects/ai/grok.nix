{ inputs, ... }:
{
  den.aspects.ai.provides.grok = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.llm-agents.grok
          pkgs.llm-agents.grok-bot
        ];

        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/Grok Bot"
          ".grok"
          ".grokbot"
        ];
      };

    darwin =
      { pkgs, ... }:
      {
        # Numtide's own build is a binary substitute; the shared-nixpkgs overlay would compile on the Mac.
        environment.systemPackages = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.grok
        ];
      };
  };
}
