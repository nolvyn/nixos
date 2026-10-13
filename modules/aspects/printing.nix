{ ... }:
{
  den.aspects.printing = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        environment.persistence."/persistent".directories = [ "/var/lib/cups" ];

        services.avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        security.apparmor.policies = lib.mkIf config.security.apparmor.enable {
          avahi-daemon = {
            state = "enforce";
            profile =
              let
                upstream = builtins.readFile "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.avahi-daemon";
                executable = "/usr/{bin,sbin}/avahi-daemon";
                additions = "  # Site-specific additions and overrides. See local/README for details.";
                nixRules = ''
                  /nix/store/*/lib/** mr,
                  /nix/store/*-avahi-daemon.conf r,
                  "${config.services.avahi.package}/etc/avahi/" r,
                  "${config.services.avahi.package}/etc/avahi/**" r,
                  "${config.services.avahi.package}/share/avahi/introspection/*.introspect" r,
                  "${config.services.avahi.package}/share/dbus-1/interfaces/org.freedesktop.Avahi.*.xml" r,
                  ${lib.concatMapStringsSep "\n" (
                    name: ''"${config.environment.etc."avahi/services/${name}.service".source}" r,''
                  ) (builtins.attrNames config.services.avahi.extraServiceFiles)}
                '';
              in
              assert lib.hasInfix executable upstream && lib.hasInfix additions upstream;
              lib.replaceStrings
                [ executable additions ]
                [ "${config.services.avahi.package}/sbin/avahi-daemon" nixRules ]
                upstream;
          };
        };

        systemd.services.avahi-daemon = lib.mkIf config.security.apparmor.enable {
          after = [ "apparmor.service" ];
          requires = [ "apparmor.service" ];
          serviceConfig.AppArmorProfile = "avahi-daemon";
          restartTriggers = [
            (pkgs.writeText "avahi-daemon-apparmor" config.security.apparmor.policies.avahi-daemon.profile)
          ];
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
