{ inputs, ... }:
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  den.aspects.impermanence = {
    nixos =
      {
        host,
        config,
        lib,
        ...
      }:
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        fileSystems."/persistent".neededForBoot = true;
        fileSystems."/home".neededForBoot = true;

        environment.persistence."/persistent" = {
          hideMounts = true;

          directories = [
            "/var/log"
            "/var/lib/nixos"
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

              ".config/celluloid"
              ".config/@filen"
              ".config/ghostty"
              ".config/Slack"
              ".config/spotify"
            ];
          };
        };

        boot.initrd.systemd.services.rollback = {
          description = "Rollback btrfs root and home subvolumes";
          wantedBy = [ "initrd.target" ];
          after = [ "systemd-cryptsetup@cryptroot.service" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = builtins.readFile ../../scripts/rollback-btrfs.sh;
        };
      };
  };
}
