# network.nix
{config, ...}:

# For more information see https://nixos.wiki/wiki/Firewall
{
  networking = {
    networkmanager.enable = false;

    wireless = {
      enable = true;
      userControlled = true;
      secretsFile = config.age.secrets.wifi-secrets.path;

      networks = {
        ZYQX5 = {
          pskRaw   = "ext:HOME_PSK";
          priority = 100;
        };

        eduroam = {
          priority = 90;
          auth = ''
            key_mgmt=WPA-EAP
            eap=PEAP
            phase2="auth=MSCHAPV2"
            identity="ext:EDUROAM_IDENTITY"
            password="ext:EDUROAM_PASSWORD"
          '';
        };
      };
    };

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
}
