{ config, lib, ... }:

{
  fileSystems."/persistent".neededForBoot = true;

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
    ++ lib.optionals (config.networking.hostName == "MoeNote") [
      "/var/lib/fprint"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  boot.initrd.systemd.services.rollback = {
    description = "Rollback btrfs root subvolume";
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
      btrfs subvolume create /btrfs_tmp/@
      umount /btrfs_tmp
    '';
  };
}
