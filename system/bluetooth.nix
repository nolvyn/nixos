{ config, pkgs, lib, ... }:

# For more information see https://nixos.wiki/wiki/Bluetooth
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true; # GUI Bluetooth Manager
}
