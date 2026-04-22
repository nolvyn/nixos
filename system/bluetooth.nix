# bluetooth.nix

# For more information see https://nixos.wiki/wiki/Bluetooth
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  services.blueman.enable = true; # GUI Bluetooth Manager
}
