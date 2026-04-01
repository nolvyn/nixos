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
          golang.go

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
    });
in

{
  environment.systemPackages = with pkgs; [
    # Text Editors / IDEs
    helix
    neovim
    personal-vscode
    zed-editor

    # Python
    uv

    # Go
    go
    (callPackage ../pkgs/wails3 {})

    # Rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt

    # C++
    gcc
  ];

  environment.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
  };
  
  programs.nix-ld.enable = true;
  programs.direnv.enable = true;

  services.flatpak = {
    packages = [
      {
        appId = "com.vscodium.codium";
        origin = "flathub";
      }
    ];

    overrides = {
      /* "com.vscodium.codium" = {
        Context = {
          shared = [ "network" ];
          sockets = [ "x11" "wayland" ];
          devices = [ "dri" ];
          filesystems = [
            "!host"
            "!home"
            "/home/weeb/.var/app/com.vscodium.codium"
            "/home/weeb/.local/share/micromamba"
            "/home/weeb/gw-analysis"
          ];
        };
      }; */
    };
  };

  hjem.users.${config.user.name} = {
    enable = true;
    files = {
      ".config/Code/User/settings.json".source = ../config/vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ../config/vscode/keybindings.json;
      ".var/app/com.vscodium.codium/config/VSCodium/User/settings.json".source = ../config/vscode/settings.json;
      ".var/app/com.vscodium.codium/config/VSCodium/User/keybindings.json".source = ../config/vscode/keybindings.json;

      ".condarc".text = ''
        channels:
          - conda-forge
        channel_priority: strict
      '';
    };
  };
}
