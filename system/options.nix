# options.nix
{ lib, ... }:

{
  options.user.name = lib.mkOption {
    type = lib.types.str;
    default = "weeb";
  };
}
