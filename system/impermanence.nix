{ config, lib, ... }:

{
  fileSystems."/persistent".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  environment.persistence."/persistent" = {
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/bluetooth"
      "/var/lib/blueman"
      "/var/lib/fprint"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/etc/NetworkManager/system-connections"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];

    users.${config.user.name} = {
      directories = [
        # Personal
        "Documents"
        "Downloads"
        "gw-analysis"
        "nixos"
        "projects"
        "school"

        # Dotfiles
        ".config"
        ".dart-tool"
        ".flutter"
        ".ipython"
        ".jupyter"
        ".local"
        ".pki"
        ".ssh"
        ".vscode"

        # Selective Cache
        ".cache/mesa_shader_cache"
        ".cache/radv_builtin_shaders"
        ".cache/sleepy-launcher"
        ".cache/spotify"
        ".cache/qtshadercache-x86_64-little_endian-lp64"
        ".cache/Proton"
        ".cache/umu"
        ".cache/umu-protonfixes"

        # Selective Config
      ]
      ++ lib.optionals (config.networking.hostName == "WeebMachine") [
        "Games"
        "torrents"
        ".steam"
      ];

      files = [
        ".gitconfig"
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
}
