{ config, pkgs, lib, ... }:

# For more information see https://wiki.nixos.org/wiki/Printing
# Can also configure it imperatively (sin) through http://localhost:631/
{
  services.printing = {
    enable = true;
    drivers = [ 
      pkgs.brlaser 
      pkgs.brgenml1lpr 
      pkgs.brgenml1cupswrapper
    ];
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
