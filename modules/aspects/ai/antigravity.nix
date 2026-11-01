{ ... }:
let
  sharedMcpServers = import ./_mcp-servers.nix;
in
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
          enableMcpIntegration = true;

          mcpServers = {
            inherit (sharedMcpServers)
              cloudflare-bindings
              cloudflare-docs
              playwright
              revenuecat
              stripe
              supabase
              ;
          };

          settings = {
            colorScheme = "dark";
            toolPermission = "proceed-in-sandbox";
          };

          permissions = {
            allow = [ "command(*)" ];
            deny = [
              "command(rm -rf)"
              "command(dd if=/dev/)"
              "command(mkfs)"
            ];
          };
        };
      };
  };
}
