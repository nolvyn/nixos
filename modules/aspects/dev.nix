{ ... }:
{
  den.aspects.dev = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [
            ".android"
            ".dart-tool"
            ".cache/qtshadercache-x86_64-little_endian-lp64"
            ".config/.wrangler"
            ".config/flutter"
            ".local/share/jupyter"
            ".local/share/uv"
            ".local/state/quickshell"
          ];
          files = [
            ".flutter"
          ];
        };

        environment.systemPackages = with pkgs; [
          # C++
          gcc

          # JS/TS
          nodejs
          typescript
          typescript-language-server

          # Lua
          lua-language-server

          # Nix
          nixd
          nixfmt

          # Python
          pyright
          python3
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
