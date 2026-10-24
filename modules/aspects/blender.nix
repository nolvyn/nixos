{ ... }:
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
            python.mcp
          ];
          # Upstream git excludes config.py (the PyPI artifact embeds telemetry
          # credentials). Supply the same interface with collection disabled.
          postPatch = ''
            cp ${../../scripts/blender-mcp-telemetry-config.py} src/blender_mcp/config.py
            substituteInPlace src/blender_mcp/consent_prompt.py \
              --replace-fail '    session_key = _session_key(ctx)' \
                '    return ""  # Nix-managed telemetry opt-out; do not ask for consent.'
          '';
          makeWrapperArgs = [
            "--set BLENDER_HOST 127.0.0.1"
            "--set BLENDER_PORT 9876"
            "--set BLENDER_MCP_DISABLE_TELEMETRY true"
            "--set BLENDER_MCP_SAFE_MODE 1"
          ];
          pythonImportsCheck = [ "blender_mcp.server" ];
          meta.mainProgram = "mcp-for-blender";
        };
        plugin = pkgs.stdenvNoCC.mkDerivation {
          # Keep the package and manifest version aligned with upstream.
          pname = "mcp-for-blender";
          version = "2.1.1";
          src = "${source}/integrations/codex/plugins/mcp-for-blender";
          nativeBuildInputs = [ pkgs.jq ];
          dontBuild = true;
          installPhase = ''
            mkdir -p "$out"
            cp -r . "$out/"
            jq --arg command ${lib.escapeShellArg (lib.getExe server)} \
              '.mcpServers["mcp-for-blender"] |= (.command = $command | .args = [])' \
              .mcp.json > "$out/.mcp.json"
          '';
        };
        # Home Manager uses the derivation version as its cache identity and
        # cleanup path; Codex needs the real upstream version directory so its
        # cache version matches the plugin manifest during refresh.
        codexPlugin = plugin // { version = "default"; };
        pluginCache = pkgs.runCommand "blender-codex-cache" { } ''
          mkdir -p "$out/${plugin.version}"
          cp -r ${plugin}/. "$out/${plugin.version}/"
          # HM cleanup addresses this alias and skips it because it is a link.
          # Codex ignores the alias and reads the real upstream version above.
          ln -s "${plugin.version}" "$out/default"
        '';
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
          # Retain its HIP build and the blender executable/desktop entry.
          inherit (base) meta;
          passthru = {
            inherit
              base
              plugin
              pluginCache
              scripts
              server
              ;
          };
        };
      in
      lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        home.packages = [ blender ];
        # The plugin owns the sole MCP registration, including viewport/form
        # capability flags. Merge with the existing plugins, never add a second
        # settings.mcp_servers entry for Blender.
        programs.codex.plugins = [ codexPlugin ];
        home.file = lib.mkIf config.programs.codex.enable {
          "${cacheRelative}/${codexPlugin.version}".enable = false;
          # No force: upgrades replace only HM-owned links, and removing the
          # aspect removes this link through normal Home Manager cleanup.
          "${cacheRelative}".source = pluginCache;
        };
        home.activation.checkBlenderPluginCache = lib.mkIf config.programs.codex.enable (
          lib.hm.dag.entryBefore
            [
              "cleanCodexPluginCache"
              "writeBoundary"
            ]
            ''
              if [ -e ${lib.escapeShellArg cacheRoot} ] && [ ! -L ${lib.escapeShellArg cacheRoot} ]; then
                echo >&2 "Blender MCP: refusing to replace a real plugin cache directory: ${cacheRoot}"
                echo >&2 "Inspect it and move it aside manually before activating; its contents have not been changed."
                exit 1
              fi
              if [ -L ${lib.escapeShellArg cacheRoot} ] && [ ! -e ${lib.escapeShellArg cacheRoot} ]; then
                echo >&2 "Blender MCP: refusing to overwrite a dangling cache link: ${cacheRoot}"
                exit 1
              fi
            ''
        );
      };
  };
}
