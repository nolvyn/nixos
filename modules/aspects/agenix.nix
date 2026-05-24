{ inputs, ... }:
{
  den.aspects.agenix = {
    nixos = { host, pkgs, lib, config, ... }: {
      environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

      age.identityPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];

      age.secrets = {
        weeb-password.file = ../../secrets/weeb-password.age;
        root-password.file = ../../secrets/root-password.age;
      }
      // lib.optionalAttrs host.isDesktop {
        syncthing-weebmachine-key.file = ../../secrets/syncthing-weebmachine-key.age;
        syncthing-weebmachine-cert.file = ../../secrets/syncthing-weebmachine-cert.age;
      }
      // lib.optionalAttrs host.isLaptop {
        syncthing-moenote-key.file = ../../secrets/syncthing-moenote-key.age;
        syncthing-moenote-cert.file = ../../secrets/syncthing-moenote-cert.age;
      };
    };
  };
}
