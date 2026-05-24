{ ... }:
{
  den.aspects.zed = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".local/share/zed"
      ];
    };

    homeManager = {
      programs.zed-editor = {
        enable = true;

        userSettings = {
          # Telemetry
          telemetry = { diagnostics = false; metrics = false; };

          # Features
          features = { inline_completion_provider = "none"; };

          # Assistant
          assistant = { enabled = false; };

          # General
          vim_mode = false;
          base_keymap = "VSCode";

          # Theme
          theme = { mode = "dark"; dark = "Matugen Dark"; light = "Matugen Light"; };

          # Fonts
          ui_font_size = 16;
          buffer_font_size = 14;
          buffer_font_family = "JetBrainsMono Nerd Font";

          # Editing
          tab_size = 4;
          detect_indent = false;
          format_on_save = "on";
          ensure_final_newline_on_save = true;
          remove_trailing_whitespace_on_save = true;
          soft_wrap = "none";
          show_whitespaces = "boundary";

          # Auto Save
          auto_save = { after_delay = { milliseconds = 1000; }; };

          # UI
          toolbar = { breadcrumbs = true; quick_actions = true; };
          gutter = { line_numbers = true; };

          # Git
          git = { git_gutter = "tracked_files"; inline_blame = { enabled = false; }; };

          # Inlay Hints
          inlay_hints = {
            enabled = true;
            show_type_hints = true;
            show_parameter_hints = true;
            show_other_hints = true;
          };

          # Direnv
          load_direnv = "shell_hook";

          # File Scan Exclusions
          file_scan_exclusions = [
            "**/.git"
            "**/.direnv"
            "**/node_modules"
            "**/target"
            "**/__pycache__"
            "**/.venv"
            "**/venv"
          ];

          # Extensions
          auto_install_extensions = { nix = true; toml = true; go = true; };

          # LSP
          lsp = {
            "rust-analyzer" = {
              binary = { path_lookup = true; };
              initialization_options = {
                check = { command = "clippy"; };
                cargo = { features = "all"; };
              };
            };
            nixd = { binary = { path_lookup = true; }; };
          };

          # Languages
          languages = {
            Nix = {
              language_servers = [ "nixd" "!nil" ];
              tab_size = 2;
              format_on_save = { external = { command = "nixfmt"; arguments = [ "-" ]; }; };
            };
            Rust = { tab_size = 4; };
            JSON = { tab_size = 2; };
            JSONC = { tab_size = 2; };
            YAML = { tab_size = 2; };
            TOML = { tab_size = 2; };
            "C++" = { tab_size = 4; };
            Go = { tab_size = 4; };
          };

          # Terminal
          terminal = {
            font_family = "JetBrainsMono Nerd Font";
            font_size = 13;
            working_directory = "current_project_directory";
            shell = { program = "/run/current-system/sw/bin/fish"; };
            blinking = "off";
            line_height = "comfortable";
            copy_on_select = false;
            dock = "bottom";
          };
        };
      };
    };
  };
}
