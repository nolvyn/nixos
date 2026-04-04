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
        ++ [
          pkgs.vscode-marketplace.adguard.adblock
          pkgs.vscode-marketplace.theqtcompany.qt-qml
          pkgs.vscode-marketplace.theqtcompany.qt-core
        ];
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

    # Go
    go
    # (callPackage ../pkgs/wails3 {})

    # Nix
    nixd
    nixfmt

    # Python
    ruff
    uv

    # Rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt
  ];

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
    };
  };
}
