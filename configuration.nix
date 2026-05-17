# configuration.nix
{ pkgs, ... }:

{
  imports = [
    ./system/agenix.nix
    ./system/audio.nix
    ./system/bluetooth.nix
    ./system/browser.nix
    ./system/btrfs.nix
    ./system/cache.nix
    ./system/dev.nix
    ./system/disko-btrfs.nix
    ./system/file.nix
    ./system/fish.nix
    ./system/fonts.nix
    ./system/git.nix
    ./system/hyprland.nix
    ./system/impermanence.nix
    ./system/keyboard.nix
    ./system/locale.nix
    ./system/location.nix
    ./system/optimizations.nix
    ./system/options.nix
    ./system/sddm.nix
    ./system/syncthing.nix
    ./system/theme.nix
    ./system/user.nix

    # Security
    ./system/security
  ];

  environment.systemPackages = with pkgs; [
    anki
    brightnessctl
    celluloid
    dunst
    exiftool
    file
    filen-desktop
    ghostty
    glib
    gzip
    jq
    lynis
    mediainfo
    nautilus
    networkmanagerapplet
    playerctl
    stable.protonvpn-gui
    resources
    ripgrep
    ripunzip
    sherlock
    slack
    spotify
    tree
    unrar
    stable.walker
    wget
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11"; # Do not change unless you know what you are doing
}
