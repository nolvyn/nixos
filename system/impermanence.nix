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
        ".android"
        ".dart-tool"
        # ".config"
        # ".local"
        ".pki"
        ".ssh"
        ".vscode"

        # Selective Cache
        ".cache/mesa_shader_cache"
        ".cache/radv_builtin_shaders"
        ".cache/spotify"
        ".cache/qtshadercache-x86_64-little_endian-lp64"
        ".cache/Proton"
        ".cache/umu"
        ".cache/umu-protonfixes"

        # Selective Config
        ".config/BraveSoftware"
        ".config/btop"
        ".config/celluloid"
        ".config/Code"
        ".config/dconf"
        ".config/dunst"
        ".config/fcitx"
        ".config/fcitx5"
        ".config/@filen"
        ".config/flutter"
        ".config/ghostty"
        ".config/gtk-3.0"
        ".config/gtk-4.0"
        ".config/hypr"
        ".config/kitty"
        ".config/mozc"
        ".config/Proton"
        ".config/Slack"
        ".config/spotify"
        ".config/Thunar"
        ".config/vesktop"
        ".config/vivaldi"
        ".config/walker"
        ".config/yazi"
        ".config/zed"

        # Selective Local
        ".local/lib/vivaldi"

        ".local/share/Anki2"
        ".local/share/fish"
        ".local/share/jupyter"
        ".local/share/keyrings"
        ".local/share/nvim"
        ".local/share/umu"
        ".local/share/uv"
        ".local/share/zed"

        ".local/state/nvim"
        ".local/state/quickshell"
        ".local/state/wireplumber"
        ".local/state/yazi"
      ]
      ++ lib.optionals config.machine.isDesktop [
        "Games"
        "torrents"
        ".cache/sleepy-launcher"
        ".config/heroic"
        ".config/qBittorrent"
        ".local/share/honkers-railway-launcher"
        ".local/share/PrismLauncher"
        ".local/share/qBittorrent"
        ".local/share/sleepy-launcher"
        ".local/share/Steam"
        ".local/state/Heroic"
      ];

      files = [
        ".flutter"
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
