{ lib, ... }:

# For more information see https://nixos.wiki/wiki/Bluetooth
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = lib.mkDefault false;
  };

  services.blueman.enable = true; # GUI Bluetooth Manager
}
