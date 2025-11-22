# firewall.nix
{ config, pkgs, lib, ... }:

# For more information see https://nixos.wiki/wiki/Firewall
{
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [];
    allowedUDPPorts = [];
    allowPing = false;
    rejectPackets = false; # Explicity ensures packets are dropped instead of rejected.
    logRefusedConnections = true; # The logs are found in the kernel logs, i.e. dmesg or journalctl -k.
  };
}
