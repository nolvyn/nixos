# network.nix
# For more information see https://nixos.wiki/wiki/Firewall
{ ... }:
{
  den.aspects.security.provides.network = {
    nixos = {
      networking = {
        networkmanager.enable = true;

        nftables.enable = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [ ];
          allowedUDPPorts = [ ];
          allowPing = false;
          rejectPackets = false; # Explicity ensures packets are silently dropped instead of rejected.
          logRefusedConnections = true; # The logs are found in the kernel logs, i.e. dmesg or journalctl -k.
        };

        stevenBlackHosts = {
          enable = true;
          blockGambling = true;
        };
      };
    };
  };
}
