{ ... }:
{
  den.aspects.vscode = {
    homeManager = { pkgs, ... }: {
      programs.vscode = {
        enable = true;

        profiles.default.extensions =
          (with pkgs.vscode-extensions; [
            jnoortheen.nix-ide
            sumneko.lua
            rust-lang.rust-analyzer
            charliermarsh.ruff
            dart-code.dart-code
            dart-code.flutter
            tamasfe.even-better-toml
          ])
          ++ (with pkgs.stable.vscode-extensions; [
            # nixpkgs-unstable jedi-language-server has a broken dep constraint (requires jedi<0.20, unstable ships 0.20.0)
            ms-python.python
            ms-python.debugpy
            ms-python.vscode-pylance
            ms-toolsai.jupyter
            ms-toolsai.jupyter-keymap
            ms-toolsai.jupyter-renderers
          ])
          ++ (with pkgs.vscode-marketplace; [
            adguard.adblock
            theqtcompany.qt-qml
            theqtcompany.qt-core
          ]);

        profiles.default.userSettings = {
          # C++
          "C_Cpp.default.cppStandard" = "c++23";

          # Dart/Fluter
          "debug.internalConsoleOptions" = "openOnSessionStart";
          "[dart]" = {
            "editor.formatOnType" = true;
            "editor.rulers" = [ 80 ];
            "editor.selectionHighlight" = false;
            "editor.tabCompletion" = "onlySnippets";
            "editor.wordBasedSuggestions" = "off";
          };

          # Nix
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
          "nix.hiddenLanguageServerErrors" = [ "textDocument/definition" ];
          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.tabSize" = 2;
          };

          # Python
          "[python]" = { "editor.defaultFormatter" = "charliermarsh.ruff"; };
          "jupyter.askForKernelRestart" = false;

          # Qt / QML
          "qt-qml.qmlls.customExePath" = "/run/current-system/sw/bin/qmlls";
          "qt-qml.doNotAskForQmllsDownload" = true;
          "qt-qml.qmlls.useQmlImportPathEnvVar" = true;
          "workbench.editorAssociations" = {
            "{git,gitlens,chat-editing-snapshot-text-model,copilot,git-graph,git-graph-3}:/**/*.qrc" = "default";
            "*.qrc" = "qt-core.qrcEditor";
          };

          # Rust
          "rust-analyzer.check.command" = "clippy";
          "rust-analyzer.cargo.features" = "all";
          "[rust]" = { "editor.defaultFormatter" = "rust-lang.rust-analyzer"; };

          # Zig
          "zig.zls.enabled" = "on";

          # Editor
          "diffEditor.ignoreTrimWhitespace" = true;
          "editor.breadcrumbs.enabled" = true;
          "editor.detectIndentation" = false;
          "editor.formatOnSave" = true;
          "editor.formatOnSaveMode" = "file";
          "editor.insertSpaces" = true;
          "editor.lineNumbers" = "on";
          "editor.minimap.enabled" = false;
          "editor.tabSize" = 4;
          "[json]" = { "editor.tabSize" = 2; };
          "[jsonc]" = { "editor.tabSize" = 2; };
          "[yaml]" = { "editor.tabSize" = 2; };

          # Explorer
          "explorer.confirmDelete" = true;
          "explorer.confirmDragAndDrop" = false;

          # Extensions
          "extensions.autoCheckUpdates" = false;
          "extensions.autoUpdate" = false;
          "extensions.ignoreRecommendations" = true;

          # Files
          "files.autoSave" = "afterDelay";
          "files.autoSaveDelay" = 1000;
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "files.trimFinalNewlines" = true;

          # Markdown
          "markdown.preview.breaks" = false;

          # Security
          "security.workspace.trust.enabled" = true;
          "security.workspace.trust.untrustedFiles" = "prompt";

          # Telemetry
          "telemetry.telemetryLevel" = "off";
          "telemetry.feedback.enabled" = false;

          # Updates
          "update.mode" = "none";
          "update.showReleaseNotes" = false;

          # Workbench
          "workbench.enableExperiments" = false;
          "workbench.settings.applyToAllProfiles" = [ ];
          "workbench.startupEditor" = "none";
          "workbench.tree.indent" = 12;

          # AI / Copilot
          "chat.agent.enabled" = false;
          "chat.autopilot.enabled" = false;
          "chat.disableAIFeatures" = true;
          "git.addAICoAuthor" = "off";
        };
      };
    };
  };
}
