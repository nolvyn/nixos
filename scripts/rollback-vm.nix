{ pkgs, ... }:
let
  metadataTools =
    pkgs.runCommand "rollback-vm-metadata" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
      mkdir -p "$out/bin"
      cc -std=gnu11 -O2 -Wall -Wextra -Werror ${./rollback-tree-metadata.c} -o "$out/bin/rollback-tree-metadata"
      cc -std=gnu11 -O2 -Wall -Wextra -Werror ${./rollback-tree-record.c} -o "$out/bin/rollback-tree-record"
    '';
  pressure = pkgs.writeText "rollback-pressure.py" ''
    import errno, os
    block = os.urandom(1024**2)
    with open('/mnt/layout/pressure-fill', 'wb', buffering=0) as target:
        try:
            for _ in range(768):
                target.write(block)
                os.fsync(target.fileno())
        except OSError as error:
            if error.errno != errno.ENOSPC:
                raise
        else:
            raise RuntimeError('Bounded fill did not produce ENOSPC')
  '';
in
{
  name = "rollback-btrfs";
  nodes.machine = {
    virtualisation = {
      emptyDiskImages = [ 512 ];
      memorySize = 512;
      cores = 1;
    };
    # Match production's Btrfs ioctl support.
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.supportedFilesystems = [ "btrfs" ];
    environment.systemPackages = [
      pkgs.btrfs-progs
      pkgs.python3
      pkgs.util-linux
      metadataTools
    ];
  };
  testScript = ''
    import re

    machine.start(allow_reboot=True)
    machine.wait_for_unit("multi-user.target")
    machine.succeed("""
      set -eu
      mkfs.btrfs -f /dev/vdb
      mkdir -p /mnt/layout /dev/mapper
      mount -o subvolid=5 /dev/vdb /mnt/layout
      ln -s /dev/vdb /dev/mapper/cryptroot
      btrfs subvolume create /mnt/layout/@
      btrfs subvolume create /mnt/layout/@home
      mkdir -p /mnt/layout/@/tmp /mnt/layout/@/var/lib
      echo root-proof > /mnt/layout/@/tmp/root-proof
      echo home-proof > /mnt/layout/@home/home-proof
    """)
    for leaf in ['srv', 'var/tmp', 'var/lib/machines', 'var/lib/portables']:
        machine.succeed(f'btrfs subvolume create /mnt/layout/@/{leaf}')
        machine.succeed(f'echo nested-proof > /mnt/layout/@/{leaf}/nested-proof')

    originals = machine.succeed(
        'rollback-tree-metadata /mnt/layout/@ && rollback-tree-metadata /mnt/layout/@home'
    )
    machine.succeed("bash ${./rollback-btrfs.sh}")
    retained = machine.succeed('btrfs subvolume list -u /mnt/layout')
    for line in originals.splitlines():
        assert line.split('|')[2] in retained, f'Original root/home/child was consumed: {line}'
    archived = machine.succeed('find /mnt/layout/@old_roots -name root-proof').splitlines()
    assert archived
    for source in archived:
        parent = source.removesuffix('/tmp/root-proof')
        machine.succeed(f'grep -qx root-proof {source}')
        for leaf in ['srv', 'var/tmp', 'var/lib/machines', 'var/lib/portables']:
            machine.succeed(f'grep -qx nested-proof {parent}/{leaf}/nested-proof')
    machine.succeed('find /mnt/layout/@old_home_roots -name home-proof -exec grep -l -x home-proof {} + | grep .')
    machine.succeed('test ! -e /mnt/layout/@/tmp/root-proof && test ! -e /mnt/layout/@home/home-proof')

    # Interrupt after publishing the preparation, before exposing either root.
    machine.succeed("bash -c 'source ${./rollback-btrfs.sh}; rb_prepare /mnt/layout'")
    machine.succeed("bash ${./rollback-btrfs.sh}")
    machine.succeed('test ! -e /mnt/layout/@rollback-pending')
    identity = machine.succeed('btrfs subvolume show /mnt/layout/@')
    match = re.search(r'^\s*UUID:\s*([0-9a-f-]+)$', identity, re.M)
    assert match is not None, 'Current root UUID missing from kernel metadata'
    root_uuid = match.group(1)

    # Fill only the guest's spare disk, which holds the rollback layout.
    machine.succeed("timeout 60s python3 ${pressure}")
    status, output = machine.execute("timeout 60s bash ${./rollback-btrfs.sh}")
    assert status in (0, 1), f'Unexpected rollback status under pressure: {status}: {output}'
    machine.succeed(f'btrfs subvolume list -u /mnt/layout | grep -F {root_uuid}')
    machine.succeed("""
      set -eu
      mkdir -p /mnt/root-check /mnt/home-check
      mount -o ro,subvol=@ /dev/vdb /mnt/root-check
      mount -o ro,subvol=@home /dev/vdb /mnt/home-check
      umount /mnt/root-check /mnt/home-check
      rm -- /mnt/layout/pressure-fill
      btrfs filesystem sync /mnt/layout
    """)
    machine.reboot()
    machine.wait_for_unit("multi-user.target")
    machine.succeed('mount -o subvolid=5 /dev/vdb /mnt/layout')
    machine.succeed(f'btrfs subvolume list -u /mnt/layout | grep -F {root_uuid}')
  '';
}
