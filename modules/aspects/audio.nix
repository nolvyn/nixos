# audio.nix

# For more information see https://wiki.nixos.org/wiki/Category:Audio
{ ... }:
{
  den.aspects.audio = {
    nixos = {
      services.pulseaudio.enable = false; # Use Pipewire, the modern sound subsystem
      security.rtkit.enable = true; # Enable RealtimeKit for audio purposes
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [ pwvucontrol ]; # Audio control GUI
    };
  };
}
