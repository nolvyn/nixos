# btrfs.nix
{ config, pkgs, lib, ... }:

{
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };
}
