{ inputs, ... }:
{
  flake-file.inputs.openai-plugins = {
    url = "github:openai/plugins";
    flake = false;
  };

  flake-file.inputs.codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

  den.aspects.ai.provides.chatgpt = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".codex" ];
        };
      };

    darwin = {
      # Homebrew owns the desktop app; its native updater remains enabled.
      homebrew.casks = [ "chatgpt" ];
    };

    homeManager =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        isNixOS = host.class == "nixos";
        isLinux = pkgs.stdenv.hostPlatform.isLinux;
        mkPlugin =
          name:
          builtins.path {
            inherit name;
            path = "${inputs.openai-plugins}/plugins/${name}";
          };
      in
      {
        # Module imports must not depend on pkgs, or evaluation recurses.
        imports = lib.optional isNixOS inputs.codex-desktop-linux.homeManagerModules.default;

        home.packages = [ pkgs.llm-agents.oh-my-codex ];

        programs = {
          codex = {
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
              model = "gpt-5.6-luna";
              model_reasoning_effort = "max";
              approval_policy = "on-request";
              sandbox_mode = "danger-full-access";

              projects."${config.home.homeDirectory}/nixos".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/folirei".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/shiori".trust_level = "trusted";

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
        }
        // lib.optionalAttrs isLinux {
          codexDesktopLinux = {
            enable = true;
            # cliPackage = pkgs.llm-agents.codex;
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
                nodejs
                openssh
                uv
              ];
            };
          };
        };
      };
  };
}
