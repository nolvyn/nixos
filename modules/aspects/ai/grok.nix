{ ... }:
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
  };
}
