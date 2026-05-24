{ ... }:
{
  den.aspects.impermanence = {
    nixos = { host, config, lib, ... }: {
      fileSystems."/persistent".neededForBoot = true;
      fileSystems."/home".neededForBoot = true;

      environment.persistence."/persistent" = {
        hideMounts = true;

        directories = [
          "/var/log"
          "/var/lib/nixos"
          "/var/lib/bluetooth"
          "/var/lib/blueman"
          "/var/lib/systemd/coredump"
          "/var/lib/systemd/timers"
          "/etc/NetworkManager/system-connections"
        ]
        ++ lib.optionals config.services.fprintd.enable [
          "/var/lib/fprint"
        ];

        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        users.${host.userName} = {
          directories = [
            # Personal
            "Downloads"
            "nixos"
            "other"
            "projects"
            "school"

            # Dotfiles
            ".pki"
            ".ssh"

            # Selective Cache
            ".cache/mesa_shader_cache"
            ".cache/radv_builtin_shaders"
            ".cache/spotify"
            ".cache/qtshadercache-x86_64-little_endian-lp64"

            # Selective Config
            ".config/celluloid"
            ".config/dconf"
            ".config/fcitx"
            ".config/fcitx5"
            ".config/@filen"
            ".config/ghostty"
            ".config/gtk-3.0"
            ".config/gtk-4.0"
            ".config/mozc"
            ".config/Slack"
            ".config/spotify"
            ".config/Thunar"
            ".config/walker"

            # Selective Local
            ".local/share/Anki2"
            ".local/share/keyrings"
            ".local/state/wireplumber"
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
