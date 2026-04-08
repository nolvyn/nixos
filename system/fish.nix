# fish.nix
{ pkgs, ... }:

{
  # For more information see https://nixos.wiki/wiki/Fish
  # Enable fish and set it as interactive shell only
  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting # Disable greeting

      set -gx EDITOR "nano --nownewlines"
      set -gx NH_FLAKE "$HOME/nixos"

      set -gx GOPATH "$HOME/.local/share/go"
      set -gx PATH "$PATH:$GOPATH/bin"
    '';
    shellAliases = {
      nhs = "nh os switch";
      des = "sudo nixos-rebuild switch --flake /home/weeb/nixos#WeebMachine";
      lap = "sudo nixos-rebuild switch --flake /home/weeb/nixos#MoeNote";
      nfu = "cd /home/weeb/nixos && nix flake update";

      ga = "cd /home/weeb/nixos && git add .";
      gc = "git commit -m";
      gp = "git push origin main";

      sure = "sudo reboot";
      rup = "ripunzip unzip-file";
    };
  };

  environment.systemPackages = with pkgs; [
    fishPlugins.grc
    grc
  ];

  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
}
