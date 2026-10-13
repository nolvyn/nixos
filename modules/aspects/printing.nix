{ ... }:
{
  den.aspects.printing = {
    nixos = { pkgs, ... }: {
      environment.persistence."/persistent".directories = [ "/var/lib/cups" ];

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
    };
  };
}
