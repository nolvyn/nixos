# systemd.nix
{ config, pkgs, lib, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.services.NetworkManager-wait-online.enable = false; # Speed up boot time
  
  systemd.services.systemd-rfkill = {
    serviceConfig = {
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      PrivateTmp = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictRealtime = true;
      SystemCallFilter = [ 
        "write" 
        "read" 
        "openat" 
        "close" 
        "brk" 
        "fstat"
        "fstatat" 
        "lseek" 
        "mmap" 
        "mprotect" 
        "munmap" 
        "rt_sigaction" 
        "rt_sigprocmask" 
        "ioctl" 
        "nanosleep" 
        "select" 
        "access" 
        "execve" 
        "getuid" 
        "arch_prctl" 
        "set_tid_address" 
        "set_robust_list" 
        "prlimit64" 
        "pread64" 
        "getrandom"
      ];
      SystemCallArchitectures = "native";
      UMask = "0077";
      IPAddressDeny = "any";
    };
  };

  systemd.services.systemd-journald = {
    serviceConfig = {
      UMask = 0077;
      PrivateNetwork = true;
      ProtectHostname = true;
      ProtectKernelModules = true;
    };
  };

  systemd.services.syslog = {
    serviceConfig = {
      PrivateNetwork= true;
      CapabilityBoundingSet= [
        "CAP_DAC_READ_SEARCH" 
        "CAP_SYSLOG" 
        "CAP_NET_BIND_SERVICE"
      ];
      NoNewPrivileges= true;
      PrivateDevices= true;
      ProtectClock= true;
      ProtectKernelLogs= true;
      ProtectKernelModules= true;
      PrivateMounts= true;
      SystemCallArchitectures= "native";
      MemoryDenyWriteExecute= true;
      LockPersonality= true;
      ProtectKernelTunables= true;
      RestrictRealtime= true;
      PrivateUsers= true;
      PrivateTmp= true;
      UMask= "0077";
      RestrictNamespace = true;
      ProtectProc= "invisible";
      ProtectHome= true;
      DeviceAllow= false;
      ProtectSystem = "full";
    };
  };

  systemd.services.NetworkManager = {
    serviceConfig = {
      NoNewPrivileges = true;
      ProtectClock = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true; 
      SystemCallArchitectures = "native";
      MemoryDenyWriteExecute= true;
      # ProtectProc = "invisible";
      # ProcSubset = "pid";  
      RestrictNamespaces = true;
      # ProtectKernelTunables= true;
      ProtectHome = true;
      PrivateTmp = true;
      UMask = "0077";
    };
  };

  systemd.services.NetworkManager-dispatcher = {
    serviceConfig = {
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      PrivateUsers = true;
      PrivateDevices = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      # RestrictAddressFamilies = "AF_INET";
      RestrictNamespaces = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
      # IPAddressDeny = "any";
    };
  };

  systemd.services.display-manager = {
    serviceConfig = {
      ProtectKernelTunables = true;
      ProtectKernelModules = true; 
      ProtectKernelLogs = true;
    };
  };
}
