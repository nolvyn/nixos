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

  programs.nh.clean = {
    enable = true;
    dates = "weekly";
    extraArgs = "--keep 25 --keep-since 30d";
  };

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
