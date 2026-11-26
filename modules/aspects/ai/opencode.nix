{ ... }:
let
  sharedMcpServers = import ./_mcp-servers.nix;
in
{
  den.aspects.ai.provides.opencode = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/opencode"
          ".local/share/opencode"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        # Enable native web search via Exa AI over MCP. Required unless the model uses an opencode/* provider.
        # See https://opencode.ai/docs/tools#websearch
        home.sessionVariables.OPENCODE_ENABLE_EXA = "1";

        programs.opencode = {
          enable = true;
          package = pkgs.llm-agents.opencode;
          enableMcpIntegration = true;
          tui.theme = "system";

          settings = {
            autoupdate = false;
            mcp =
              builtins.mapAttrs
                (_: server: {
                  type = "local";
                  command = [ server.command ] ++ server.args;
                  enabled = true;
                })
                {
                  inherit (sharedMcpServers)
                    cloudflare-docs
                    stripe
                    supabase
                    ;
                };

            permission = {
              edit = "allow";
              webfetch = "allow";
              websearch = "allow";
              "mcp-nixos_*" = "allow";

              read = {
                "*" = "allow";
              };

              bash = {
                "*" = "allow";
              };
            };
          };
        };
      };
  };
}
