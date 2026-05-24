# dev.nix

{ ... }:
{
  den.aspects.dev = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName} = {
        directories = [
          ".android"
          ".dart-tool"
          ".config/flutter"
          ".local/share/jupyter"
          ".local/share/nvim"
          ".local/share/uv"
          ".local/state/nvim"
          ".local/state/quickshell"
        ];
        files = [
          ".flutter"
        ];
      };

      environment.systemPackages = with pkgs; [
        # Text Editors / IDEs
        neovim

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

      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          wayland
          libxkbcommon
          vulkan-loader
        ];
      };

      programs.direnv.enable = true;

      users.users.${host.userName}.extraGroups = [ "kvm" ]; # Needed for Android emulator hardware acceleration
    };
  };
}
