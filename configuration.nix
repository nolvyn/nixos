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
    ./system/file.nix
    # ./system/firefox.nix
    ./system/fish.nix
    # ./system/flatpak.nix
    ./system/fonts.nix
    ./system/git.nix
    ./config/hypr/hypr.nix
    ./system/keyboard.nix
    ./system/locale.nix
    ./system/optimizations.nix
    # ./system/printing.nix
    ./system/sddm.nix
    ./system/syncthing.nix
    ./system/theme.nix
    ./system/user.nix
    ./system/disko-btrfs.nix
    ./system/impermanence.nix
    ./system/location.nix

    # Security
    ./system/security/network.nix
    ./system/security/general.nix
    ./system/security/kernel.nix
    ./system/security/systemd.nix
    ./system/security/openssh.nix
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
    networkmanagerapplet
    # onlyoffice-desktopeditors
    playerctl
    stable.protonvpn-gui
    resources
    ripgrep
    ripunzip
    slack
    spotify
    thunar
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
