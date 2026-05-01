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
    ./config/hypr/hypr.nix
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
    btop
    celluloid
    dunst
    exiftool
    fastfetch
    file
    filen-desktop
    ghostty
    glib
    gzip
    jq
    kitty
    lynis
    mediainfo
    nautilus
    networkmanagerapplet
    # onlyoffice-desktopeditors
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
    vesktop
    stable.walker
    wget
    yazi
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11"; # Do not change unless you know what you are doing
}
