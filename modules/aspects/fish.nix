# Enable fish and configure it for interactive use.
{ lib, ... }:
{
  den.aspects.fish = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".local/share/fish"
        ];
      };

    homeManager =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        linuxAliases = lib.optionalAttrs (lib.hasSuffix "linux" host.system) {
          nhs = "nh os switch";
          sure = "sudo reboot";
          rup = "ripunzip unzip-file";
          matu = "matugen image --source-color-index 0";
          oc = "opencode";
        };
      in
      {
        home.sessionVariables = {
          EDITOR = "nano -L";
          GOPATH = "${config.home.homeDirectory}/.local/share/go";
        };

        home.sessionPath = [ "${config.home.homeDirectory}/.local/share/go/bin" ];

        home.packages = [ pkgs.grc ];

        programs.fish = {
          interactiveShellInit = "set fish_greeting";
          shellAliases = {
            nfu = "cd $HOME/nixos && nix run .#write-flake && nix flake update";
            nfw = "cd $HOME/nixos && nix run .#write-flake && nix flake check";

            ga = "cd $HOME/nixos && git add .";
            gc = "git commit -m";
            gp = "git push origin main";
          }
          // linuxAliases;

          plugins = [
            {
              name = "grc";
              src = pkgs.fishPlugins.grc.src;
            }
          ];
        };
      };
  };
}
