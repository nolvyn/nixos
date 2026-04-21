# dev.nix
{ config, pkgs, ... }:

let
  personal-vscode = (
    pkgs.vscode-with-extensions.override {
      vscode = pkgs.vscode;

      vscodeExtensions =
        (with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
          rust-lang.rust-analyzer
          golang.go

          charliermarsh.ruff
          ms-python.python
          ms-python.debugpy
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers

          tamasfe.even-better-toml
        ])
        ++ (with pkgs.vscode-marketplace; [
          adguard.adblock
          theqtcompany.qt-qml
          theqtcompany.qt-core
        ]);
    }
  );
in

{
  environment.systemPackages = with pkgs; [
    # Text Editors / IDEs
    helix
    neovim
    personal-vscode
    zed-editor

    # C++
    gcc

    # Dart/Flutter
    flutter

    # Go
    go
    # (callPackage ../pkgs/wails3 {})

    # Nix
    nixd
    nixfmt

    # Python
    ruff
    uv

    # Qt/QML
    kdePackages.qtdeclarative
    kdePackages.qtimageformats
    kdePackages.qtmultimedia
    kdePackages.qtsvg
    quickshell

    # Rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt
  ];

  system.userActivationScripts.quickshellQmllsIni = {
    text = ''
      mkdir -p "$HOME/.config/quickshell"
      if [ ! -f "$HOME/.config/quickshell/.qmlls.ini" ]; then
        touch "$HOME/.config/quickshell/.qmlls.ini"
      fi
    '';
  };

  environment.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
  };

  programs.nix-ld.enable = true;
  programs.direnv.enable = true;

  hjem.users.${config.user.name} = {
    enable = true;
    files = {
      ".config/Code/User/settings.json".source = ../config/vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;
      ".config/zed/settings.json".source = ../config/zed/settings.json;
    };
  };
}
