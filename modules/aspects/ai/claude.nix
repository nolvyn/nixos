{ inputs, ... }:
{
  den.aspects.ai.provides.claude = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.llm-agents.claude-desktop ];

        environment.persistence."/persistent".users.${host.userName} = {
          directories = [
            ".claude"
            {
              directory = ".config/Claude";
              mode = "0700";
            }
          ];
          files = [ ".claude.json" ];
        };
      };

    darwin = {
      homebrew.casks = [ "claude" ];
    };

    homeManager =
      { pkgs, ... }:
      {
        programs.claude-code = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
          enableMcpIntegration = true;

          settings = {
            theme = "dark";
            alwaysThinkingEnabled = true;
            showTurnDuration = true;
            defaultMode = "default";
            remoteControlAtStartup = true;

            extraKnownMarketplaces = {
              "android-cli-plugin".source = {
                source = "directory";
                path = "${inputs.android-cli-plugin}";
              };
            };

            enabledPlugins = {
              "android-cli@android-cli-plugin" = true;
              "claude-security@claude-plugins-official" = true;
              "pr-review-toolkit@claude-plugins-official" = true;
              "sentry@claude-plugins-official" = true;
              "cloudflare@claude-plugins-official" = true;
              "code-simplifier@claude-plugins-official" = true;
              "code-review@claude-plugins-official" = true;
              # The Claude account also syncs a copy of this one; without this it loads anyway.
              "rust-analyzer-lsp@synced" = false;
              "security-guidance@claude-plugins-official" = true;
              "stripe@claude-plugins-official" = true;
              "supabase@claude-plugins-official" = true;
            };

            permissions = {
              allow = [
                "Bash(*)"
                "WebFetch(domain:*)"
                "WebSearch"
                "mcp__nixos__*"
              ];
            };
          };
        };
      };
  };
}
