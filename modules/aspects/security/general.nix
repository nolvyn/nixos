# general.nix

{ ... }:
{
  den.aspects.security.provides.general = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".local/share/keyrings"
      ];

      # Keyring/Wallet Stuff
      services.gnome.gnome-keyring.enable = true;
      programs.seahorse.enable = true; # GUI Keyring Manager

      security.sudo.enable = false;
      security.sudo-rs.enable = true;

      # CVE-2026-111943: match the upstream NixOS distrust policy.
      security.pki.caCertificateBlacklist = [
        "Comodo AAA Services root"
        "emSign ECC Root CA - G3"
        "emSign Root CA - C1"
        "emSign ECC Root CA - C3"
      ];

      nix.settings.allowed-users = [ "@users" ];

      # For more information see https://mynixos.com/nixpkgs/option/environment.memoryAllocator.provider
      # environment.memoryAllocator.provider = "libc"; # scudo and mimalloc mess up my system

      boot.kernel.sysctl = {
        "dev.tty.ldisc_autoload" = 0;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "fs.suid_dumpable" = 0;
        "kernel.kptr_restrict" = 2;
        "kernel.sysrq" = 0;

        "kernel.unprivileged_bpf_disabled" = 1;
        # Exposed only when the running kernel provides the BPF JIT hardening sysctl.
        "net.core.bpf_jit_harden" = 2;

        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;

        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.default.log_martians" = 1;

        # Setting this to 1 breaks my internet
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;

        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;

        "fs.protected_hardlinks" = 1;
        "fs.protected_symlinks" = 1;
        "kernel.dmesg_restrict" = 1;
        "kernel.randomize_va_space" = 2;
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;
        "net.ipv4.tcp_syncookies" = 1;
      };

      security.apparmor = {
        enable = true;
        killUnconfinedConfinables = true;
        packages = [ pkgs.apparmor-profiles ];
        # Confine the actual executable reached by NixOS's capability wrapper.
        # Packaged desktop profiles often allow everything; loading them alone
        # would give a confined-looking label without useful restrictions.
        policies.nixos-ping = {
          state = "enforce";
          profile = ''
            abi <abi/4.0>,
            include <tunables/global>

            profile nixos-ping "${pkgs.iputils}/bin/ping" {
              include <abstractions/base>
              include <abstractions/consoles>
              include <abstractions/nameservice>

              capability net_raw,
              network inet raw,
              network inet6 raw,

              "${pkgs.iputils}/bin/ping" mr,
              /nix/store/*/lib/** mr,
              @{PROC}/sys/net/ipv6/conf/all/disable_ipv6 r,
            }
          '';
        };
      };

      # Breaks Rocket League
      /*
        fileSystems."/proc" = {
          device = "proc";
          fsType = "proc";
          options = [
            "defaults"
            "hidepid=invisible"
          ];
          neededForBoot = true;
        };
      */

      services.dbus.implementation = "broker";

      boot.initrd.compressor = "zstd";
      boot.initrd.compressorArgs = [
        "-3"
        "-T0"
      ];
    };
  };
}
