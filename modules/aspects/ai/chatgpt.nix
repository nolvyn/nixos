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
        # Use Numtide's pinned dependencies for Codex binary substitutes.
        # Shared nixpkgs or local overrides change the derivation and miss that cache;
        # on macOS the shared-nixpkgs build of 0.171.0 also fails in aws-lc-sys.
        codexPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
        desktopProxyPython = pkgs.python3.withPackages (ps: [ ps.websockets ]);
        desktopCli = pkgs.writeShellScriptBin "codex" ''
          exec ${desktopProxyPython}/bin/python3 \
            ${../../../scripts/codex-desktop-proxy.py} \
            ${lib.getExe codexPackage} "$@"
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

        home.sessionVariables = linuxSessionVariables;
        systemd.user.sessionVariables = linuxSessionVariables;

        programs = {
          codex = {
            enable = true;
            package = codexPackage;
            # Off since 2026-11-15 to save memory: programs.mcp only adds mcp-nixos, one process per Codex session.
            # Uncomment to restore.
            # enableMcpIntegration = true;

            plugins = map mkPlugin [
              "cloudflare"
              "codex-security"
              "github"
              "stripe"
              "supabase"
            ];

            settings = {
              theme = "dark";
              model = "gpt-6.2-sol";
              model_reasoning_effort = "medium";
              approval_policy = "on-request";
              sandbox_mode = "danger-full-access";

              projects."${config.home.homeDirectory}/nixos".trust_level = "trusted";
              projects."${config.home.homeDirectory}/projects/gw-analysis".trust_level = "trusted";
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
              package = codexPackage;
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
