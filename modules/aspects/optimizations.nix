# optimizations.nix

# For more information see https://nixos.wiki/wiki/Storage_optimization
{ ... }:
{
  den.aspects.optimizations = {
    nixos = { host, pkgs, ... }: {
      nix.settings = {
        max-jobs = "auto";
        cores = 0;
        min-free = 100 * 1024 * 1024 * 1024; # 100 GiB
        max-free = 200 * 1024 * 1024 * 1024; # 200 GiB
      };

      nix.optimise = {
        automatic = true;
        dates = [ "daily" ];
      };

      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 10 --keep-since 20d";
        };
        flake = host.flakeDir;
      };

      services.journald.extraConfig = ''
        MaxRetentionSec=30day
      '';

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
    };
  };
}
