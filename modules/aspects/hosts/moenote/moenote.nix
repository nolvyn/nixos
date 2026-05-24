{ den, ... }:
{
  den.aspects.MoeNote = {
    nixos = {
      services.fprintd.enable = true;
      services.upower.enable = true;
    };

    homeManager = { host, config, ... }: {
      home.file.".config/hypr/hypridle.conf".source =
        config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/hypr/hypridle.conf";
    };

    includes = [
      den.aspects.common
      den.aspects.tlp
    ];
  };
}
