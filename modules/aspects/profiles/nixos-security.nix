{ den, ... }:
{
  # These aspects currently persist state under /persistent. Keep them out of
  # the generic base so a future server can choose a different storage policy.
  den.aspects.nixosSecurity = {
    includes = with den.aspects; [
      agenix
      security.general
      security.kernel
      security.network
      security.ssh
      security.systemd
      user
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.lynis ];
      };
  };
}
