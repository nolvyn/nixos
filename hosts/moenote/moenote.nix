{ config, pkgs, lib, ... }:

{
  imports = [
    ./moenote-hardware.nix
    ../../system/tlp.nix
  ];

  environment.systemPackages = with pkgs; [
    # arduino
  ];

  networking.hostName = "MoeNote";

  users.users.${config.user.name} = {
    # extraGroups = [ "dialout" ];
  };

  services.upower.enable = true;

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;
    };
  };

  # DO NOT CHANGE **YOUR** DEFAULT VALUE HERE UNLESS YOU KNOW WHAT YOU ARE DOING 
  # For more information see https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
