# dev.nix
{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    micromamba

    neovim
    vscode
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
