{ ... }:
{
  den.aspects.omniwm = {
    darwin = { ... }: {
      system.defaults.spaces.spans-displays = false;
      system.defaults.trackpad.TrackpadThreeFingerHorizSwipeGesture = 0;
    };

    homeManager =
      {
        host,
        config,
        pkgs,
        ...
      }:
      let
        omniwm = pkgs.unstable.omniwm.overrideAttrs (
          _finalAttrs: _previousAttrs: {
            version = "0.7.5";
            src = pkgs.fetchurl {
              url = "https://github.com/OmniNull/OmniWM/releases/download/v0.7.5/OmniWM-v0.7.5.zip";
              hash = "sha256-oV/KNBGojdBviTUyjChiY9V6RMe8wiVUd+KTA/qUzM4=";
            };
          }
        );
      in
      {
        programs.omniwm = {
          enable = true;
          package = omniwm;
        };

        xdg.configFile."omniwm/settings.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/omniwm/settings.toml";
      };
  };
}
