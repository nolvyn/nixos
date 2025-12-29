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
        ++ (pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "adblock";
            publisher = "adguard";
            version = "1.1.17";
            sha256 = "sha256-EbNKHjWIbn7YkaWyIjXF9wSqw4ql4n4DpACQkwT5L+0=";
          }
        ]);
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
