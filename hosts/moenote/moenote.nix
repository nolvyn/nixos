{ config, pkgs, lib, ... }:

{
  imports = [
    ./moenote-hardware.nix
    ../../system/tlp.nix
  ];

  environment.systemPackages = with pkgs; [];

  networking.hostName = "MoeNote";

  users.users.${config.user.name} = {};

  services.upower.enable = true;

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;
    };
  };
}
