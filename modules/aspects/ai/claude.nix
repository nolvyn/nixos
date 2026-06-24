{ ... }:
{
  den.aspects.ai.provides.claude = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".claude" ];
          files = [ ".claude.json" ];
        };
      };

    homeManager =
      { pkgs, ... }:
      {
        programs.claude-code = {
          enable = true;
          package = pkgs.llm-agents.claude-code;
          enableMcpIntegration = true;

          settings = {
            theme = "dark";
            alwaysThinkingEnabled = true;
            showTurnDuration = true;
            defaultMode = "default";

            extraKnownMarketplaces = {
              "omc" = {
                source = {
                  source = "github";
                  repo = "Yeachan-Heo/oh-my-claudecode";
                };
              };
            };

            enabledPlugins = {
              "claude-md-management@claude-plugins-official" = true;
              "cloudflare@claude-plugins-official" = true;
              "code-simplifier@claude-plugins-official" = true;
              "code-review@claude-plugins-official" = true;
              "commit-commands@claude-plugins-official" = true;
              "feature-dev@claude-plugins-official" = true;
              "frontend-design@claude-plugins-official" = true;
              "lua-lsp@claude-plugins-official" = true;
              "oh-my-claudecode@omc" = true;
              "playwright@claude-plugins-official" = true;
              "pyright-lsp@claude-plugins-official" = true;
              "revenuecat@claude-plugins-official" = true;
              "rust-analyzer-lsp@claude-plugins-official" = true;
              "security-guidance@claude-plugins-official" = true;
              "stripe@claude-plugins-official" = true;
              "supabase@claude-plugins-official" = true;
              "typescript-lsp@claude-plugins-official" = true;
            };

            permissions = {
              allow = [
                "Bash(*)"
                "WebFetch(domain:*)"
                "WebSearch"
                "mcp__nixos__*"
              ];
              deny = [
                "Read(~/.ssh/**)"
                "Read(~/.age/**)"
                "Read(**/*.key)"
                "Read(**/*.pem)"
                "Bash(rm -rf /*)"
                "Bash(rm -rf ~*)"
                "Bash(dd if=/dev/*)"
                "Bash(mkfs*)"
                "Bash(curl * | bash)"
                "Bash(wget * | sh)"
                "Bash(wget * | bash)"
              ];
            };
          };
        };
      };
  };
}
