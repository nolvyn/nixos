# btrfs.nix

{ ... }:
{
  den.aspects.btrfs = {
    nixos = {
      services.btrfs.autoScrub = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}
