{ ... }:
{
  den.aspects.tailscale = {
    nixos = { ... }: {
      services.tailscale.enable = true;
      environment.persistence."/persistent".directories = [ "/var/lib/tailscale" ];
    };
  };
}
