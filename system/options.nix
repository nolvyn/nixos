# options.nix
{ config, pkgs, lib, ... }:

{
  options.user.name = lib.mkOption {
    type = lib.types.str;
    default = "weeb";
  };
}
