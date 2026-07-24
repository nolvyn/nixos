{ inputs, ... }:
{
  flake-file.inputs.openai-plugins = {
    url = "github:openai/plugins";
    flake = false;
  };

  # Unofficial wrapper that runs OpenAI's Codex Desktop (Electron GUI) on Linux.
  flake-file.inputs.codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

  den.aspects.ai.provides.codex = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".codex" ];
        };
      };

    homeManager =
      { pkgs, ... }:
      let
        mkPlugin =
          name:
          builtins.path {
            inherit name;
            path = "${inputs.openai-plugins}/plugins/${name}";
          };
      in
      {
        imports = [ inputs.codex-desktop-linux.homeManagerModules.default ];

        home.packages = [ pkgs.llm-agents.oh-my-codex ];

        # Codex Desktop GUI. cliPackage wraps the launcher/.desktop entry so it
        # starts with CODEX_CLI_PATH pointing at our Codex CLI package. All
        # optional features enabled: leaving `package` unset lets the module
        # auto-select the combined computer-use-ui + remote-mobile-control
        # variant from the two enable flags below.
        programs.codexDesktopLinux = {
          enable = true;
          cliPackage = pkgs.llm-agents.codex;
          computerUseUi.enable = true;
          remoteMobileControl.enable = true;
          remoteControl = {
            enable = true;
            package = pkgs.llm-agents.codex;
            extraPackages = with pkgs; [
              bash
              coreutils
              findutils
              git
              gnugrep
              gnused
              openssh
              nodejs
              uv
            ];
          };
        };

        programs.codex = {
          enable = true;
          package = pkgs.llm-agents.codex;
          enableMcpIntegration = true;

          skills = "${pkgs.llm-agents.oh-my-codex}/share/oh-my-codex/skills";

          plugins = map mkPlugin [
            "cloudflare"
            "codex-security"
            "github"
            "stripe"
            "supabase"
          ];

          rules.default = ''
            prefix_rule(pattern = ["rm", "-rf", "/"], decision = "deny")
            prefix_rule(pattern = ["rm", "-rf", "~"], decision = "deny")
            prefix_rule(pattern = ["dd", "if=/dev/"], decision = "deny")
            prefix_rule(pattern = ["mkfs"], decision = "deny")
          '';

          settings = {
            theme = "dark";
            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

            projects."/home/weeb/nixos".trust_level = "trusted";
            projects."/home/weeb/projects/folirei".trust_level = "trusted";
            projects."/home/weeb/projects/shiori".trust_level = "trusted";

            mcp_servers.playwright = {
              command = "npx";
              args = [ "@playwright/mcp@latest" ];
            };
            /*
              mcp_servers.revenuecat = {
                command = "npx";
                args = [
                  "mcp-remote"
                  "https://mcp.revenuecat.ai/mcp"
                ];
              };
            */
          };
        };
      };
  };
}
