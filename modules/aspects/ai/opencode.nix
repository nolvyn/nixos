{ ... }:
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
        home.packages = [ pkgs.llm-agents.oh-my-opencode ];

        # Enable the native websearch tool (uses Exa AI via MCP).
        # Required unless using an opencode/* provider model.
        # See https://opencode.ai/docs/tools#websearch
        home.sessionVariables.OPENCODE_ENABLE_EXA = "1";

        home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "1";

        programs.opencode = {
          enable = true;
          package = pkgs.llm-agents.opencode;
          enableMcpIntegration = true;
          tui.theme = "system";
          skills = "${pkgs.llm-agents.oh-my-opencode}/lib/oh-my-opencode/packages/shared-skills/skills";

          settings = {
            autoupdate = false;
            lsp = true;
            plugin = [
              "opencode-notificator"
              "opencode-vibeguard"
              "opencode-sentry-monitor"
              "opencode-dynamic-context-pruning"
            ];

            mcp = {
              lsp-daemon = {
                type = "local";
                command = [
                  "node"
                  "${pkgs.llm-agents.oh-my-opencode}/lib/oh-my-opencode/packages/lsp-daemon/dist/cli.js"
                ];
                enabled = true;
              };
              playwright = {
                type = "local";
                command = [
                  "npx"
                  "@playwright/mcp@latest"
                ];
                enabled = true;
              };
              cloudflare-bindings = {
                type = "local";
                command = [
                  "npx"
                  "mcp-remote"
                  "https://bindings.mcp.cloudflare.com/mcp"
                ];
                enabled = true;
              };
              cloudflare-docs = {
                type = "local";
                command = [
                  "npx"
                  "mcp-remote"
                  "https://docs.mcp.cloudflare.com/mcp"
                ];
                enabled = true;
              };
              stripe = {
                type = "local";
                command = [
                  "npx"
                  "mcp-remote"
                  "https://mcp.stripe.com"
                ];
                enabled = true;
              };
              supabase = {
                type = "local";
                command = [
                  "npx"
                  "mcp-remote"
                  "https://mcp.supabase.com/mcp"
                ];
                enabled = true;
              };
              revenuecat = {
                type = "local";
                command = [
                  "npx"
                  "mcp-remote"
                  "https://mcp.revenuecat.ai/mcp"
                ];
                enabled = true;
              };
            };

            permission = {
              edit = "allow";
              webfetch = "allow";
              websearch = "allow";
              "mcp-nixos_*" = "allow";
              lsp = "allow";

              read = {
                "*" = "allow";
                "~/.ssh/**" = "deny";
                "~/.age/**" = "deny";
                "**/*.key" = "deny";
                "**/*.pem" = "deny";
              };

              bash = {
                "*" = "allow";
                "rm -rf /*" = "deny";
                "rm -rf ~*" = "deny";
                "dd if=/dev/*" = "deny";
                "mkfs*" = "deny";
                "curl * | bash" = "deny";
                "wget * | sh" = "deny";
                "wget * | bash" = "deny";
              };
            };
          };
        };
      };
  };
}
