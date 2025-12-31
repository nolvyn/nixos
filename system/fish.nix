# fish.nix
{ config, pkgs, lib, ... }:

{
  # For more information see https://nixos.wiki/wiki/Fish
  # Enable fish and set it as interactive shell only
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      set -gx MAMBA_ROOT_PREFIX "$HOME/.local/share/micromamba"
      set -gx MAMBA_EXE "${pkgs.micromamba}/bin/micromamba"
      set -gx CONDA_OVERRIDE_ARCHSPEC "haswell"
      $MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
    '';
    shellAliases = {
      des = "cd && doas nixos-rebuild switch --flake /home/weeb/nixos#WeebMachine";
      lap = "cd && doas nixos-rebuild switch --flake /home/weeb/nixos#MoeNote";
      nfu = "cd /home/weeb/nixos && nix flake update && cd";

      ga = "cd /home/weeb/nixos && git add *";
      gc = "git commit -m";
      gp = "git push origin main && cd";

      dore = "doas reboot";
      rup = "ripunzip unzip-file";
      fcode = "flatpak run com.visualstudio.code";

      sudo = "doas";
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
