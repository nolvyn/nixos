# optimizations.nix
{ pkgs, ... }:

# For more information see https://nixos.wiki/wiki/Storage_optimization
{
  nix.settings = {
    max-jobs = "auto";
    cores = 0;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 25 --keep-since 30d";
    };
    flake = "$HOME/nixos"; # Doesn't do anything with fish
  };

  services.fwupd.enable = true; # Updates for certain hardware

  systemd.user.services.empty-trash = {
    description = "Empty trash files older than 30 days";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30";
    };
  };

  systemd.user.timers.empty-trash = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  environment.systemPackages = with pkgs; [
    trash-cli
  ];
}
