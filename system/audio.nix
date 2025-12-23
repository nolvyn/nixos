{ config, pkgs, lib, ... }:

# For more information see https://wiki.nixos.org/wiki/Category:Audio
{
  services.pulseaudio.enable = false; # Use Pipewire, the modern sound subsystem
  security.rtkit.enable = true; # Enable RealtimeKit for audio purposes
  services.pipewire = {
    enable = true;  
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = false;
  };

  environment.systemPackages = with pkgs; [
    pwvucontrol # Audio control GUI
  ];
}
