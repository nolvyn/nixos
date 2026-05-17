{ config, ... }:

{
  imports = [ ../base.nix ];

  home.file.".config/hypr/hypridle.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/config/hypr/hypridle.conf";
}
