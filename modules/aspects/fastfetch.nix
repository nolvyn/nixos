{ lib, ... }:
{
  den.aspects.fastfetch = {
    homeManager =
      { host, ... }:
      let
        isLinux = lib.hasSuffix "linux" host.system;
        installAgeCommand =
          if isLinux then
            "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days"
          else
            "birth_install=$(stat -f %B /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
      in
      {
        programs.fastfetch = {
          enable = true;

          settings = {
            display.separator = " ";

            logo = {
              height = 19;
              padding = {
                left = 3;
                top = 2;
              };
              source = "${host.flakeDir}/assets/icons/roxy2.jpg";
              width = 42;
            };

            modules = [
              "break"
              "break"
              {
                keyWidth = 10;
                type = "title";
              }
              "break"
              {
                key = " ";
                keyColor = "34";
                type = "os";
              }
              {
                key = " ";
                keyColor = "34";
                type = "kernel";
              }
              {
                key = " ";
                keyColor = "34";
                type = "packages";
              }
              {
                key = " ";
                keyColor = "34";
                type = "shell";
              }
              "break"
              "break"
              {
                key = " ";
                keyColor = "34";
                type = "terminal";
              }
            ]
            ++ lib.optional isLinux {
              key = "  ";
              keyColor = "34";
              type = "wm";
            }
            ++ [
              {
                key = " ";
                keyColor = "34";
                type = "uptime";
              }
              {
                key = "󱦟 ";
                keyColor = "34";
                text = installAgeCommand;
                type = "command";
              }
            ]
            ++ lib.optional isLinux {
              key = "󰝚 ";
              keyColor = "34";
              type = "media";
            }
            ++ [
              "break"
              "break"
              {
                key = "  ";
                keyColor = "blue";
                type = "cpu";
              }
            ]
            ++ lib.optional isLinux {
              key = "  ";
              keyColor = "blue";
              type = "gpu";
            }
            ++ [
              {
                key = " ";
                keyColor = "blue";
                type = "memory";
              }
              {
                key = "󰋊 ";
                keyColor = "blue";
                type = "disk";
              }
              "break"
              "break"
            ];
          };
        };
      };
  };
}
