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
              "nixos"
              "other"
              "projects"
              "school"

              # Selective Cache
              ".cache/spotify"

              # Selective Config
              ".config/celluloid"
              ".config/@filen"
              ".config/ghostty"
              ".config/Slack"
              ".config/spotify"
              ".config/walker"

              # Selective Local
              ".local/share/Anki2"
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
          script = ''
            mkdir /btrfs_tmp
            mount -o subvolid=5 /dev/mapper/cryptroot /btrfs_tmp

            if [[ -e /btrfs_tmp/@ ]]; then
              mkdir -p /btrfs_tmp/@old_roots
              timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@)" "+%Y-%m-%-d_%H:%M:%S")
              mv /btrfs_tmp/@ "/btrfs_tmp/@old_roots/$timestamp"
            fi

            if [[ -e /btrfs_tmp/@home ]]; then
              mkdir -p /btrfs_tmp/@old_home_roots
              timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@home)" "+%Y-%m-%-d_%H:%M:%S")
              mv /btrfs_tmp/@home "/btrfs_tmp/@old_home_roots/$timestamp"
            fi

            delete_subvolume_recursively() {
              IFS=$'\n'
              for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
              done
              btrfs subvolume delete "$1"
            }

            for i in $(find /btrfs_tmp/@old_roots/ -maxdepth 1 -mtime +30); do
              delete_subvolume_recursively "$i"
            done

            for i in $(find /btrfs_tmp/@old_home_roots/ -maxdepth 1 -mtime +30); do
              delete_subvolume_recursively "$i"
            done

            btrfs subvolume create /btrfs_tmp/@
            btrfs subvolume create /btrfs_tmp/@home
            umount /btrfs_tmp
          '';
        };
      };
  };
}
