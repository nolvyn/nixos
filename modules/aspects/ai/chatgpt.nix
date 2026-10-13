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
          directories = [
            ".codex"
            ".config/Codex"
            {
              # Includes Linux settings, Electron flags, and private pairing keys.
              directory = ".config/codex-desktop";
              mode = "0700";
            }
            ".local/state/codex-desktop"
          ];
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
        linuxSessionVariables = lib.optionalAttrs isLinux {
          CODEX_LINUX_DISABLE_USAGE_REPORTING = "1";
        };
        desktopProxyPython = pkgs.python3.withPackages (ps: [ ps.websockets ]);
        desktopCli = pkgs.writeShellScriptBin "codex" ''
          exec ${desktopProxyPython}/bin/python3 \
            ${../../../scripts/codex-desktop-proxy.py} \
            ${lib.getExe pkgs.llm-agents.codex} "$@"
        '';
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
        home.sessionVariables = linuxSessionVariables;
        systemd.user.sessionVariables = linuxSessionVariables;

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
              prefix_rule(pattern = ["rm", "-rf", "/"], decision = "forbidden")
              prefix_rule(pattern = ["rm", "-rf", "~"], decision = "forbidden")
              prefix_rule(pattern = ["dd", "if=/dev/"], decision = "forbidden")
              prefix_rule(pattern = ["mkfs"], decision = "forbidden")
            '';

            settings = {
              theme = "dark";
              model = "gpt-6.1-sol";
              model_reasoning_effort = "high";
              approval_policy = "on-request";
              sandbox_mode = "danger-full-access";

              projects."${config.home.homeDirectory}/nixos".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/folirei".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/shiori".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/gw-analysis".trust_level = "trusted";

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
            # Desktop's JSONL transport needs framing for the service's WebSocket socket.
            cliPackage = desktopCli;
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
