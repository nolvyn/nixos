{ config, pkgs, lib, ... }:

{
  # For more information see https://nixos.wiki/wiki/Fish
  # Enable fish and set it as interactive shell only
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
    shellAliases = {
      des = "cd && sudo nixos-rebuild switch --flake /home/weeb/nixos#WeebMachine";
      lap = "cd && sudo nixos-rebuild switch --flake /home/weeb/nixos#MoeNote";
      nfu = "cd /home/weeb/nixos && nix flake update && cd";

      ga = "cd /home/weeb/nixos && git add *";
      gc = "git commit -m";
      gp = "git push origin main && cd";

      sure = "sudo reboot";
      rup = "ripunzip unzip-file";
      codium = "flatpak run com.vscodium.codium";
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
