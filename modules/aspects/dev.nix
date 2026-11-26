{ ... }:
{
  den.aspects.dev = {
    nixos =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      let
        blorfRoles = {
          blorf-credential = 941;
          blorf-authority = 942;
          blorf-browser = 943;
        };
      in
      {
        # Separate system accounts keep Blorf's stored sign-ins out of the user's reach.
        users.users =
          lib.mapAttrs (name: id: {
            uid = id;
            group = name;
            isSystemUser = true;
            home = "/var/lib/${name}";
            createHome = false;
            hashedPassword = "!";
          }) blorfRoles
          // {
            ${host.userName} = {
              extraGroups = [ "kvm" ]; # Needed for Android emulator hardware acceleration
              linger = true;
            };
          };

        users.groups = lib.mapAttrs (_: id: { gid = id; }) blorfRoles;

        environment.persistence."/persistent".directories =
          (lib.mapAttrsToList (name: _: {
            directory = "/var/lib/${name}";
            user = name;
            group = name;
            mode = "0700";
          }) blorfRoles)
          ++ [
            {
              directory = "/var/lib/blorf-credential-keys";
              user = "blorf-credential";
              group = "blorf-credential";
              mode = "0700";
            }
          ];

        systemd.tmpfiles.rules = [
          "d /var/lib/blorf-credential/vault 0700 blorf-credential blorf-credential -"
          "d /run/blorf-credential 0755 root root -"
          "d /run/blorf-credential/authority 2710 blorf-credential blorf-authority -"
          "d /run/blorf-credential/browser 2710 blorf-credential blorf-browser -"
        ];

        systemd.user.services.blorf-personal-start =
          let
            units = "/home/${host.userName}/projects/business/.local/blorf-personal/config/systemd/user";
          in
          {
            description = "Start the personal blorf install";
            wantedBy = [ "default.target" ];
            unitConfig.ConditionPathExists = "${units}/blorf-server.service";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl --user link --runtime ${units}/blorf-server.service ${units}/blorf-supervisor.service && ${pkgs.systemd}/bin/systemctl --user start blorf-server.service blorf-supervisor.service'";
            };
          };

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
        # Unstable pins Dart 3.13.0. Use the shared project minimum (3.13.7) with nixpkgs packaging.
        agentDart = pkgs.unstable.dart-bin.overrideAttrs (old: {
          version = "3.13.7";
          src = old.src.overrideAttrs {
            hash =
              {
                x86_64-linux = "sha256-65mu0mbvvLYVxq4hwS9Sz+k1ufIIvMxf6n9kwh6Gcik=";
                aarch64-darwin = "sha256-n5cu4eETnLT4RfNcfHe+8mndLscnsjn7F6Lry2bQ+y8=";
              }
              .${pkgs.stdenv.hostPlatform.system};
          };
        });
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
          ++ [
            agentDart
            pkgs.unstable.android-cli
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
