{ config, pkgs, lib, ... }:

# For more information see https://nixos.wiki/wiki/Storage_optimization
{
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
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
