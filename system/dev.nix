# dev.nix
{ config, pkgs, lib, ... }:

let
  personal-vscode =
    (pkgs.vscode-with-extensions.override {
      vscode = pkgs.vscode;

      vscodeExtensions =
        (with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
          rust-lang.rust-analyzer
          ms-python.python
          ms-python.debugpy
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.vscode-jupyter-slideshow
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
        ])
        ++ [
          pkgs.vscode-marketplace.adguard.adblock
          pkgs.vscode-marketplace.theqtcompany.qt-qml
          pkgs.vscode-marketplace.theqtcompany.qt-core
        ];
    });
in

{
  environment.systemPackages = with pkgs; [
    micromamba

    neovim
    personal-vscode
    zed-editor

    gcc

    zig

    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
  ];

  environment.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
  };
  
  programs.direnv.enable = true;

  hjem.users.${config.user.name} = {
    enable = true;
    files = {
      ".config/Code/User/settings.json".source = ../config/vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;
      ".var/app/com.visualstudio.code/config/Code/User/settings.json".source = ../config/vscode/settings.json;
      ".var/app/com.visualstudio.code/config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;

      # "cpp/.envrc".text = "use flake";

      ".condarc".text = ''
        channels:
          - conda-forge
        channel_priority: strict
      '';
    };
  };
}
