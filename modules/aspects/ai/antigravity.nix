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
          enableMcpIntegration = true;

          mcpServers = {
            playwright = {
              command = "npx";
              args = [ "@playwright/mcp@latest" ];
            };
            cloudflare-bindings = {
              command = "npx";
              args = [
                "mcp-remote"
                "https://bindings.mcp.cloudflare.com/mcp"
              ];
            };
            cloudflare-docs = {
              command = "npx";
              args = [
                "mcp-remote"
                "https://docs.mcp.cloudflare.com/mcp"
              ];
            };
            stripe = {
              command = "npx";
              args = [
                "mcp-remote"
                "https://mcp.stripe.com"
              ];
            };
            supabase = {
              command = "npx";
              args = [
                "mcp-remote"
                "https://mcp.supabase.com/mcp"
              ];
            };
            revenuecat = {
              command = "npx";
              args = [
                "mcp-remote"
                "https://mcp.revenuecat.ai/mcp"
              ];
            };
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
