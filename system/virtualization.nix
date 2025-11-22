{ config, pkgs, lib, ... }:

{
  # For more information see https://nixos.wiki/wiki/Virt-manager
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  users.users.${config.user.name} = {
    extraGroups = [ "libvirtd" ];
  };

  # For more information see https://wiki.nixos.org/wiki/Waydroid
  # virtualisation.waydroid.enable = true;
}
