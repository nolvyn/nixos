# btrfs.nix

{
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };
}
