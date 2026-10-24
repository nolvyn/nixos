{ ... }:
{
  den.aspects.dev = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [
            ".android"
            ".cache/qtshadercache-x86_64-little_endian-lp64"
            ".config/.wrangler"
            ".config/flutter"
            ".dart-tool"
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
            libxkbcommon
            vulkan-loader
            wayland
          ];
        };

        users.users.${host.userName}.extraGroups = [ "kvm" ]; # Needed for Android emulator hardware acceleration
      };

    darwin = {
      programs.mas.packages = {
        "Xcode" = 497799835;
      };
    };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        projectsDirectory = "${config.home.homeDirectory}/projects";
        # Keep supported development clients on the NixOS distrust policy.
        linuxSessionVariables = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
          UV_SYSTEM_CERTS = "true";
        };
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

        home.packages =
          with pkgs;
          [
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
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
            (pkgs.writeShellScriptBin "astraeus-dev-setup" ''
              exec ${pkgs.python3}/bin/python3 ${../../scripts/astraeus-dev-setup.py} "$@"
            '')
          ];

        home.sessionVariables = linuxSessionVariables;
        systemd.user.sessionVariables = linuxSessionVariables;

        programs.direnv.enable = true;
      };
  };
}
