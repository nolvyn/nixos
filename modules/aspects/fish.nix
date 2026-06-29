# Enable fish and set it as interactive shell only
# NH_FLAKE needed for fish specifically
{ ... }:
{
  den.aspects.fish = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".local/share/fish"
        ];

        programs.fish = {
          enable = true;
          shellInit = ''
            set fish_greeting

            set -gx EDITOR "nano -L"
            set -gx NH_FLAKE "${host.flakeDir}"

            set -gx GOPATH "$HOME/.local/share/go"
            set -gx PATH "$PATH:$GOPATH/bin"
          '';
          shellAliases = {
            nhs = "nh os switch";
            nfu = "cd $HOME/nixos && nix run .#write-flake && nix flake update";
            nfw = "cd $HOME/nixos && nix run .#write-flake && nix flake check";

            ga = "cd $HOME/nixos && git add .";
            gc = "git commit -m";
            gp = "git push origin main";

            sure = "sudo reboot";
            rup = "ripunzip unzip-file";

            matu = "matugen image --source-color-index 0";
            oc = "opencode";
          };
        };

        environment.systemPackages = with pkgs; [
          fishPlugins.grc
          grc
        ];

        programs.bash.interactiveShellInit = ''
          if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
          then
            shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
            exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
          fi
        '';
      };
  };
}
