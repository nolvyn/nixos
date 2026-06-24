{ ... }:
{
  den.aspects.ai.provides.cursor = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/Cursor"
          ".cursor"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        programs.cursor = {
          enable = true;
          package = pkgs.unstable.code-cursor;

          profiles.default = {
            enableUpdateCheck = true;
            enableExtensionUpdateCheck = true;
            enableMcpIntegration = true;

            extensions =
              with pkgs.vscode-extensions;
              [
                jnoortheen.nix-ide
                rust-lang.rust-analyzer
                charliermarsh.ruff
              ]
              ++ (with pkgs.stable.vscode-extensions; [
                ms-python.python
                ms-python.debugpy
                ms-python.vscode-pylance
              ]);

            userSettings = {
              "editor.formatOnSave" = true;
              "editor.formatOnSaveMode" = "file";
              "editor.detectIndentation" = false;
              "editor.tabSize" = 4;
              "files.autoSave" = "onWindowChange";
              "files.trimTrailingWhitespace" = true;
              "files.insertFinalNewline" = true;
              "diffEditor.ignoreTrimWhitespace" = true;
              "editor.breadcrumbs.enabled" = true;
              "editor.minimap.enabled" = false;

              "security.workspace.trust.enabled" = true;
              "security.workspace.trust.untrustedFiles" = "prompt";
              "telemetry.telemetryLevel" = "off";
              "update.mode" = "none";
              "extensions.autoUpdate" = false;

              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nixd";
              "[nix]" = {
                "editor.defaultFormatter" = "jnoortheen.nix-ide";
                "editor.tabSize" = 2;
              };

              "[python]" = {
                "editor.defaultFormatter" = "charliermarsh.ruff";
              };

              "rust-analyzer.check.command" = "clippy";
              "rust-analyzer.cargo.features" = "all";
              "[rust]" = {
                "editor.defaultFormatter" = "rust-lang.rust-analyzer";
              };
            };
          };
        };
      };
  };
}
