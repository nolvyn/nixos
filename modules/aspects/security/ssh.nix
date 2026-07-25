{ ... }:
{
  den.aspects.security.provides.ssh = {
    nixos = { host, ... }: {
      environment.persistence."/persistent" = {
        files = [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];
        users.${host.userName}.directories = [ ".ssh" ];
      };

      services.openssh = {
        enable = true;
        openFirewall = false;
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          PermitRootLogin = "no"; # Must be set to "yes" on target machine for NixOS Anywhere install
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
  };
}
