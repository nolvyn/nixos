{ inputs, ... }:
{
  flake-file.inputs.stevenblack-hosts.url = "github:StevenBlack/hosts";

  den.aspects.security.provides.network = {
    nixos = {
      imports = [ inputs.stevenblack-hosts.nixosModule ];
      environment.persistence."/persistent".directories = [
        "/etc/NetworkManager/system-connections"
      ];

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
