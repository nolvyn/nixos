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
        ])
        ++ [
          pkgs.vscode-marketplace.adguard.adblock
          pkgs.vscode-marketplace.theqtcompany.qt-qml
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
  
  qt.enable = true;
  programs.direnv.enable = true;

  hjem.users.${config.user.name} = {
    enable = true;
    files = {
      ".config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;
      ".config/Code/User/settings.json".source    = ../config/vscode/settings.json;

      # "cpp/.envrc".text = "use flake";

      ".condarc".text = ''
        channels:
          - conda-forge
        channel_priority: strict
      '';
    };
  };
}
