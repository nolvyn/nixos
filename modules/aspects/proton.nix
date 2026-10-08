{ ... }:
{
  den.aspects.proton = {
    nixos = { host, pkgs, ... }: {
      environment.systemPackages = [ pkgs.proton-vpn ];

      # Settings survive rollback; cache and logs can be regenerated.
      # Shared keyring and NetworkManager persistence live in security aspects.
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/Proton/VPN"
      ];
    };

    darwin = {
      homebrew.casks = [ "protonvpn" ];
    };
  };
}
