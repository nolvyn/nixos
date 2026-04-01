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
      # ProtectProc = "invisible";
      # ProcSubset = "pid";
      PrivateTmp = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
      IPAddressDeny = "any";
      RestrictSUIDSGID = true;
      ProtectKernelLogs = true;
      ProtectHostname = true;
    };
  };

  systemd.services.systemd-journald = {
    serviceConfig = {
      UMask = "0077";
      ProtectHostname = true;
      ProtectKernelModules = true;
      RestrictSUIDSGID = true;
    };
  };

  systemd.services.NetworkManager = {
    serviceConfig = {
      NoNewPrivileges = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      # SystemCallArchitectures = "native";
      # ProtectProc = "invisible";
      # ProcSubset = "pid";
      # RestrictNamespaces = true;
      # ProtectKernelTunables = true;
      # PrivateTmp = true;
      RestrictSUIDSGID = true;
      ProtectHostname = true;
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
      # ProtectProc = "invisible";
      # ProcSubset = "pid";
      NoNewPrivileges = true;
      LockPersonality = true;
      # RestrictAddressFamilies = "AF_INET";
      # RestrictNamespaces = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
      # IPAddressDeny = "any";
      RestrictSUIDSGID = true;
    };
  };
}
