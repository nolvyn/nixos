# general.nix
{ config, pkgs, lib, ... }:

{
  # Keyring/Wallet Stuff
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;  # GUI Keyring Manager

  security.sudo.enable = false;
  security.sudo.execWheelOnly = true;

  security.doas.enable = true;
  security.doas.extraRules = [{
    users = ["weeb"];
    keepEnv = false;
    persist = true;
  }];

  environment.systemPackages = [ pkgs.git ]; # Needed for system rebuilds in flake based systems

  nix.settings.allowed-users = [ "@users" ];

  # SSH
  services.openssh.enable = false;

  # For more information see https://mynixos.com/nixpkgs/option/environment.memoryAllocator.provider
  # environment.memoryAllocator.provider = "libc"; # scudo and mimalloc mess up my system

  /* boot.kernel.sysctl = {
    "dev.tty.ldisc_autoload" = 0;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
    "kernel.kptr_restrict" = 2;
    "kernel.sysrq" = 0;
    
    "kernel.unprivileged_bpf_disabled" = 1;
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
    # killUnconfinedConfinables = true;
    packages = [pkgs.apparmor-profiles];
  };

  fileSystems."/proc" = {
    device = "proc";
    fsType = "proc";
    options = ["defaults" "hidepid=1"];
    neededForBoot = true;
  };

  services.dbus.implementation = "broker"; */
}
