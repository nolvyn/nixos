{ config, pkgs, lib, ... }:

# For more information see https://nixos.wiki/wiki/Storage_optimization
{
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
