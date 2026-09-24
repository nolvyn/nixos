{ ... }:
{
  den.aspects.dev = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        projectsDirectory = "${config.home.homeDirectory}/projects";
      in
      {
        home.activation.ensureProjectsDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          projectsDirectory=${lib.escapeShellArg projectsDirectory}

          if [[ -e "$projectsDirectory" && ! -d "$projectsDirectory" ]]; then
            printf >&2 'error: refusing to replace non-directory projects path: %s\n' "$projectsDirectory"
            exit 1
          fi

          run ${pkgs.coreutils}/bin/mkdir -p "$projectsDirectory"
        '';

        home.packages = with pkgs; [
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

          # Rust
          cargo
          clippy
          rust-analyzer
          rustc
          rustfmt
        ];

        programs.direnv.enable = true;
      };

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

          # Qt/QML
          kdePackages.qtdeclarative
          kdePackages.qtimageformats
          kdePackages.qtmultimedia
          kdePackages.qtsvg
          quickshell
        ];

        programs.nix-ld = {
          enable = true;
          libraries = with pkgs; [
            wayland
            libxkbcommon
            vulkan-loader
          ];
        };

        users.users.${host.userName}.extraGroups = [ "kvm" ]; # Needed for Android emulator hardware acceleration
      };
  };
}
