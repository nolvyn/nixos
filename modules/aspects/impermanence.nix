{ inputs, ... }:
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  den.aspects.impermanence = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        rollbackMetadataTools = pkgs.runCommand "rollback-tree-metadata" {
          nativeBuildInputs = [ pkgs.stdenv.cc ];
        } ''
          mkdir -p "$out/bin"
          cc -std=gnu11 -O2 -Wall -Wextra -Werror \
            ${../../scripts/rollback-tree-metadata.c} -o "$out/bin/rollback-tree-metadata"
          cc -std=gnu11 -O2 -Wall -Wextra -Werror \
            ${../../scripts/rollback-tree-record.c} -o "$out/bin/rollback-tree-record"
        '';
        persistence = config.environment.persistence."/persistent";
        scopes = [ persistence ] ++ builtins.attrValues persistence.users;
        directories = lib.concatMap (scope: scope.directories) scopes;
        files = lib.concatMap (scope: scope.files) scopes;
        reportManifest = pkgs.writeText "persistent-storage-report-manifest.json" (
          builtins.toJSON (
            map (entry: {
              source = "${entry.persistentStoragePath}${entry.dirPath}";
              target = entry.dirPath;
            }) directories
            ++ map (entry: {
              source = "${entry.persistentStoragePath}${entry.filePath}";
              target = entry.filePath;
            }) files
          )
        );
      in
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        fileSystems."/persistent".neededForBoot = true;
        fileSystems."/home".neededForBoot = true;

        environment.persistence."/persistent" = {
          hideMounts = true;

          directories = [
            "/var/log"
            "/var/lib/nixos"
            {
              directory = "/var/lib/persistent-storage-report";
              user = host.userName;
              group = config.users.users.${host.userName}.group;
              mode = "0700";
            }
          ]
          ++ lib.optionals config.services.fprintd.enable [
            "/var/lib/fprint"
          ];

          files = [ "/etc/machine-id" ];

          users.${host.userName} = {
            directories = [
              # Personal
              "Downloads"
              "mext"
              "nixos"
              "other"
              "projects"
              "school"

              ".cache/spotify"

              ".config/@filen"
              ".config/ghostty"
              ".config/Slack"
              ".config/spotify"
            ];
          };
        };

        systemd.services.persistent-storage-report = {
          description = "Monthly persistence size and declaration report";
          unitConfig.RequiresMountsFor = [ "/persistent" ];
          serviceConfig = {
            Type = "oneshot";
            User = host.userName;
            StateDirectory = "persistent-storage-report";
            StateDirectoryMode = "0700";
            UMask = "0077";
            ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/persistent-storage-report.py} --root /persistent --manifest ${reportManifest} --state-dir /var/lib/persistent-storage-report";
            TimeoutStartSec = "30min";
            Nice = 19;
            IOSchedulingClass = "idle";
            MemoryMax = "512M";
            NoNewPrivileges = true;
            PrivateNetwork = true;
            PrivateTmp = true;
            ProtectHome = "read-only";
            ProtectSystem = "strict";
            ReadOnlyPaths = [ "/persistent" ];
          };
        };

        systemd.timers.persistent-storage-report = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "monthly";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        boot.initrd.systemd.extraBin = {
          findmnt = "${pkgs.util-linux}/bin/findmnt";
          rollback-tree-metadata = "${rollbackMetadataTools}/bin/rollback-tree-metadata";
          rollback-tree-record = "${rollbackMetadataTools}/bin/rollback-tree-record";
          sha256sum = "${pkgs.coreutils}/bin/sha256sum";
          timeout = "${pkgs.coreutils}/bin/timeout";
        };

        boot.initrd.systemd.services.rollback = {
          description = "Rollback btrfs root and home subvolumes";
          wantedBy = [ "initrd.target" ];
          after = [ "systemd-cryptsetup@cryptroot.service" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = builtins.readFile ../../scripts/rollback-btrfs.sh;
        };
      };

    homeManager =
      { lib, pkgs, ... }:
      lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        # Existing Fish universal-variable persistence keeps this to once per report.
        programs.fish.interactiveShellInit = lib.mkAfter ''
          set -l storage_notice /var/lib/persistent-storage-report/notice.txt
          if test -r "$storage_notice"
            set -l storage_report_id (${pkgs.coreutils}/bin/head -n 1 "$storage_notice")
            if test -n "$storage_report_id"; and test "$storage_report_id" != "$persistent_storage_report_seen"
              ${pkgs.coreutils}/bin/cat "$storage_notice"
              set -U persistent_storage_report_seen "$storage_report_id"
            end
          end
        '';
      };
  };
}
