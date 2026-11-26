{ inputs, ... }:
{
  den.aspects.blender = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/blender"
          ".local/share/blender"
        ];
      };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        # Advertise the immutable plugin source directly and leave the mutable cache to Codex.
        # Guard the temporary Home Manager compatibility patch.
        codexModuleRoot = "${inputs.home-manager}/modules/programs/codex";
        codexModulePatched = import ../../scripts/codex-local-source.nix {
          inherit lib codexModuleRoot;
        };
        serverLauncherRelative = ".local/share/codex-plugins/blender-mcp-server";
        serverLauncher = "${config.home.homeDirectory}/${serverLauncherRelative}";
        # Server, bundled add-on, and Codex UI must move together.
        source = pkgs.fetchFromGitHub {
          owner = "ahujasid";
          repo = "mcp-for-blender";
          rev = "7a0373ec9199183cb460068c4f96aed9c579fb4f";
          hash = "sha256-bL8x9AMHbQKX0e3pLDrlzndY5xUD1ApKBPaRCTHn45Q=";
        };
        python = pkgs.unstable.python3Packages;
        server = python.buildPythonApplication {
          pname = "mcp-for-blender";
          version = "2.1.9";
          src = source;
          pyproject = true;
          build-system = [ python.setuptools ];
          dependencies = [
            python.httpx
            # The pinned server requires mcp >=1.26,<2; python.mcp tracks 2.x.
            python.mcp_1
          ];
          # Upstream git omits config.py. PyPI embeds telemetry credentials. Provide the same interface with collection off.
          postPatch = ''
            cp ${../../scripts/blender-mcp-telemetry-config.py} src/blender_mcp/config.py
            substituteInPlace src/blender_mcp/consent_prompt.py \
              --replace-fail '    session_key = _session_key(ctx)' \
                '    return ""  # Nix-managed telemetry opt-out; do not ask for consent.'
          '';
          makeWrapperArgs = [
            "--set"
            "BLENDER_HOST"
            "127.0.0.1"
            "--set"
            "BLENDER_PORT"
            "9876"
            "--set"
            "BLENDER_MCP_DISABLE_TELEMETRY"
            "true"
            "--set"
            "BLENDER_MCP_SAFE_MODE"
            "1"
          ];
          pythonImportsCheck = [ "blender_mcp.server" ];
          meta.mainProgram = "mcp-for-blender";
        };
        plugin = pkgs.stdenvNoCC.mkDerivation {
          pname = "mcp-for-blender";
          version = "2.1.1";
          src = "${source}/integrations/codex/plugins/mcp-for-blender";
          nativeBuildInputs = [
            pkgs.jq
            pkgs.python3
          ];
          dontBuild = true;
          installPhase = ''
            python3 ${../../scripts/blender-codex-source-check.py} .
            mkdir -p "$out"
            cp -r . "$out/"
            jq --arg command ${lib.escapeShellArg serverLauncher} \
              '.mcpServers["mcp-for-blender"] |= (.command = $command | .args = [])' \
              .mcp.json > "$out/.mcp.json"
            python3 ${../../scripts/blender-codex-source-check.py} "$out" \
              --command ${lib.escapeShellArg serverLauncher}
          '';
        };
        codexPlugin = plugin // {
          codexLocalSource = "./.local/share/codex-plugins/mcp-for-blender";
        };
        codexDir =
          if config.home.preferXdgDirectories then
            "${config.xdg.configHome}/codex"
          else
            "${config.home.homeDirectory}/.codex";
        cacheRoot = "${codexDir}/plugins/cache/home-manager/mcp-for-blender";
        cacheRelative = lib.removePrefix "${config.home.homeDirectory}/" cacheRoot;
        scripts = pkgs.runCommand "blender-mcp-scripts" { } ''
          mkdir -p "$out/addons" "$out/startup"
          ln -s ${source}/addon.py "$out/addons/blender_mcp.py"
          ln -s ${../../scripts/blender-mcp-startup.py} "$out/startup/nixos_blender_mcp.py"
        '';
        base = pkgs.unstable.pkgsRocm.blender;
        blender = pkgs.symlinkJoin {
          name = "blender-${base.version}";
          paths = [ base ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/blender" \
              --prefix BLENDER_SYSTEM_SCRIPTS : ${scripts} \
              --set BLENDERMCP_NO_UPDATE_CHECK 1
          '';
          # The pinned Blender already supplies requests and its Python deps.
          inherit (base) meta;
          passthru = {
            inherit
              base
              plugin
              scripts
              server
              ;
          };
        };
      in
      {
        disabledModules = [ codexModuleRoot ];
        imports = [ codexModulePatched ];
        config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          home.packages = [ blender ];
          # Merge the plugin into the existing list. It owns Blender's sole MCP registration and viewport/form flags;
          # never add a settings.mcp_servers entry for Blender.
          programs.codex.plugins = [ codexPlugin ];
          home.activation.checkBlenderPluginCache = lib.mkIf config.programs.codex.enable (
            lib.hm.dag.entryBefore [ "cleanCodexPluginCache" "writeBoundary" ] ''
              managedFiles=""
              if [[ -v oldGenPath ]]; then
                managedFiles="$(readlink -e "$oldGenPath/home-files")"
              fi
              ${lib.getExe pkgs.python3} ${../../scripts/blender-codex-source-check.py} \
                ${lib.escapeShellArg cacheRoot} --cache \
                --command ${lib.escapeShellArg serverLauncher} \
                --managed-home-files "$managedFiles" \
                --pending-home-files "$newGenPath/home-files" \
                --system-home-manager-unit ${lib.escapeShellArg "/run/current-system/etc/systemd/system/home-manager-${config.home.username}.service"} \
                --cache-relative ${lib.escapeShellArg cacheRelative} \
                --home ${lib.escapeShellArg config.home.homeDirectory} \
                --owned-link .local/share/codex-plugins/mcp-for-blender \
                --owned-link ${lib.escapeShellArg serverLauncherRelative}
            ''
          );
          home.file = lib.mkIf config.programs.codex.enable {
            "${cacheRelative}/${codexPlugin.version}".enable = false;
            # Codex owns this mutable cache root, including any user additions.
            "${cacheRelative}".enable = false;
            ".local/share/codex-plugins/mcp-for-blender".source = plugin;
            "${serverLauncherRelative}".source = lib.getExe server;
          };
        };
      };
  };
}
