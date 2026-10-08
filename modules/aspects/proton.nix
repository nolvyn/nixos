{ ... }:
{
  den.aspects.proton = {
    nixos = { host, pkgs, ... }: {
      environment.systemPackages = [ pkgs.proton-vpn ];

      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/Proton"
      ];
    };

    darwin = {
      homebrew.casks = [ "protonvpn" ];
    };
  };
}
