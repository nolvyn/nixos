# printing.nix
{ pkgs, ... }:

# For more information see https://wiki.nixos.org/wiki/Printing
{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      brlaser
      brgenml1lpr
      brgenml1cupswrapper
      cups-filters
      cups-browsed
    ];
  };
}
