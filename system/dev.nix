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

          charliermarsh.ruff
          ms-python.python
          ms-python.debugpy
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers

          dart-code.dart-code
          dart-code.flutter

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
    neovim
    personal-vscode
    zed-editor

    # C++
    gcc

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

  programs.nix-ld.enable = true;
  programs.direnv.enable = true;

  users.users.${config.user.name}.extraGroups = [ "kvm" ]; # Needed for Android emulator hardware acceleration

  hjem.users.${config.user.name} = {
    files = {
      ".config/Code/User/settings.json".source = ../config/vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;
      ".config/zed/settings.json".source = ../config/zed/settings.json;
    };
  };
}
