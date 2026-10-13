# systemd.nix

{ ... }:
{
  den.aspects.security.provides.systemd = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        environment.persistence."/persistent".directories = [
          "/var/lib/systemd/coredump"
          "/var/lib/systemd/timers"
        ];

        systemd.coredump.settings.Coredump = {
          ExternalSizeMax = "1G";
          MaxUse = "1G";
          ProcessSizeMax = "1G";
        };

        # Override only the upstream coredump line, preserving every other rule.
        # Use mtime so inspecting a dump does not extend its retention.
        environment.etc."tmpfiles.d/systemd.conf".source =
          pkgs.runCommand "systemd-tmpfiles-coredump-retention.conf" { }
            ''
              cp ${config.systemd.package}/example/tmpfiles.d/systemd.conf "$out"
              substituteInPlace "$out" --replace-fail \
                'd /var/lib/systemd/coredump 0755 root root 2w' \
                'd /var/lib/systemd/coredump 0755 root root m:7d'
            '';

        # Bootloader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.systemd-boot.configurationLimit = 50;
        boot.loader.timeout = 1;

        systemd.services.display-manager.after = lib.mkForce [
          "systemd-user-sessions.service"
        ];

        systemd.services.NetworkManager-wait-online.enable = false; # Speed up boot time

        systemd.services.systemd-rfkill = {
          serviceConfig = {
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            # ProtectProc = "invisible";
            # ProcSubset = "pid";
            PrivateTmp = true;
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            LockPersonality = true;
            RestrictRealtime = true;
            SystemCallArchitectures = "native";
            UMask = "0077";
            IPAddressDeny = "any";
            RestrictSUIDSGID = true;
            ProtectKernelLogs = true;
            ProtectHostname = true;
          };
        };

        systemd.services.systemd-journald = {
          serviceConfig = {
            UMask = "0077";
            ProtectHostname = true;
            ProtectKernelModules = true;
            RestrictSUIDSGID = true;
          };
        };

        systemd.services.NetworkManager = {
          serviceConfig = {
            NoNewPrivileges = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            # SystemCallArchitectures = "native";
            # ProtectProc = "invisible";
            # ProcSubset = "pid";
            # RestrictNamespaces = true;
            # ProtectKernelTunables = true;
            # PrivateTmp = true;
            RestrictSUIDSGID = true;
            ProtectHostname = true;
          };
        };

        systemd.services.NetworkManager-dispatcher = {
          serviceConfig = {
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectKernelLogs = true;
            ProtectHostname = true;
            ProtectClock = true;
            # ProtectProc = "invisible";
            # ProcSubset = "pid";
            NoNewPrivileges = true;
            LockPersonality = true;
            # RestrictAddressFamilies = "AF_INET";
            # RestrictNamespaces = true;
            SystemCallArchitectures = "native";
            UMask = "0077";
            # IPAddressDeny = "any";
            RestrictSUIDSGID = true;
          };
        };
      };
  };
}
