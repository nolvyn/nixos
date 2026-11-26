{ ... }:
{
  den.aspects.ai.provides.antigravity = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".gemini"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        programs.antigravity-cli = {
          enable = true;
          package = pkgs.llm-agents.antigravity-cli;

          # Merge into a writable settings.json so agy can rewrite it. A read-only link blocked Home Manager
          # activation at boot and left the entire home unconfigured.
          mutableSettings = true;

          settings = {
            colorScheme = "dark";
          };

          permissions = {
            allow = [ "command(*)" ];
          };
        };
      };
  };
}
