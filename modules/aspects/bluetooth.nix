# For more information see https://nixos.wiki/wiki/Bluetooth
{ ... }:
{
  den.aspects.bluetooth = {
    nixos = { lib, ... }: {
      environment.persistence."/persistent".directories = [
        "/var/lib/bluetooth"
        "/var/lib/blueman"
      ];

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = lib.mkDefault false;
      };
      services.blueman.enable = true; # GUI Bluetooth Manager
    };
  };
}
