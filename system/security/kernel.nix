# kernel.nix
{ config, pkgs, lib, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  /* # security.lockKernelModules = true; # Causes too many problems. Will get back to later
  security.protectKernelImage = true;

  boot.kernelModules = [
    # Needed for VPN
    "curve25519-x86_64"
    "dummy"
    "ip6_udp_tunnel"
    "libchacha20poly1305"
    "libcurve25519-generic"
    "udp_tunnel"
    "wireguard"
  ];

  boot.blacklistedKernelModules = [
    # Network Protocols
    "ax25"
    "dccp"
    "netrom"
    "rds"
    "rds_rdma"
    "rds_tcp"
    "rose"
    "sctp"
    "tipc"

    # Infrared
    "irda"
    "nsc_ircc"
    "sir_dev"

    # Filesystems
    "adfs"
    "affs"
    "befs"
    "bfs"
    "cifs"
    "cramfs"
    "efs"
    "erofs"
    "exofs"
    "f2fs"
    "freevxfs"
    "gfs2"
    "hfs"
    "hfsplus"
    "hpfs"
    "jffs2"
    "jfs"
    "ksmbd"
    "minix"
    "nfs"
    "nfsv3"
    "nfsv4"
    "nilfs2"
    "ntfs"
    "omfs"
    "qnx4"
    "qnx6"
    "sysv"
    "udf"
    "ufs"

    # Storage & Devices
    "cdrom"
    "floppy"
    "mtd"
    "mtd_blkdevs"
    "mtd_nand_core"
    "mtdblock"
    "pata_ali"
    "pata_amd"
    "pata_artop"
    "pata_cmd64x"
    "pata_hpt366"
    "pata_hpt37x"
    "pata_it821x"
    "pata_jmicron"
    "pata_marvell"
    "pata_mpiix"
    "pata_netcell"
    "pata_ns87415"
    "pata_oldpiix"
    "pata_pcmcia"
    "pata_pdc2027x"
    "pata_qdi"
    "pata_radisys"
    "pata_rz1000"
    "pata_sch"
    "pata_serverworks"
    "pata_sil680"
    "pata_sis"
    "pata_sl82c105"
    "pata_triflex"
    "pata_via"

    # Audio & Multimedia
    "ad1889"
    "als300"
    "als4000"
    "atiixp"
    "au88x0"
    "azt3328"
    "cmpci"
    "cs423x"
    "cs46xx"
    "emu10k1"
    "ens1370"
    "ens1371"
    "es1938"
    "es1968"
    "fm801"
    "ice1712"
    "ice1724"
    "korg1212"
    "maestro3"
    "nm256"
    "rme32"
    "rme96"
    "rme9652"
    "sb16"
    "sb_mixer"
    "sbawe"
    "sonicvibes"
    "sscape"
    "trident"
    "via82xx"
    "vx222"
    "ymfpci"

    # Input
    "gameport"
    "joydev"
    "joystick"
    "paddle"
    "serio_raw"

    # Virtualization
    "vboxdrv"
    "vboxnetadp"
    "vboxnetflt"
    "vboxpci"
    "vmmon"
    "vmnet"

    # FireWire
    "firewire_core"
    "firewire_ohci"
    "firewire_sbp2"

    # Other
    "mac_hid"
    "vivid"
  ]; */
}
