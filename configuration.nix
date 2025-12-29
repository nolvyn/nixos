# configuration.nix
{ pkgs, config, lib, inputs, ... }:

{
  imports = [
    ./system/audio.nix
    ./system/bluetooth.nix
    ./system/brave.nix
    ./system/btrfs.nix
    ./system/dev.nix
    ./system/file.nix
    # ./system/firefox.nix
    ./system/fish.nix
    ./system/flatpak.nix
    ./system/fonts.nix
    ./system/git.nix
    ./system/hypr.nix
    ./system/keyboard.nix
    ./system/locale.nix
    ./system/optimizations.nix
    # ./system/printing.nix
    ./system/sddm.nix
    ./system/theme.nix
    ./system/user.nix

    # Security
    # ./system/security/firejail.nix
    ./system/security/firewall.nix
    ./system/security/general.nix
    ./system/security/kernel.nix
    ./system/security/systemd.nix
  ];
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    dunst
    exiftool
    fastfetch
    filen-desktop
    ghostty
    kdePackages.dolphin
    kitty
    lynis
    mediainfo
    networkmanagerapplet
    onlyoffice-desktopeditors
    playerctl
    protonvpn-gui
    quickshell
    resources
    ripgrep
    ripunzip
    slack
    spotify
    tree
    unrar
    vesktop
    vlc
    walker
    waybar
    wget
    yazi
    zoom-us
  ];

  nixpkgs.config.allowUnfree = true;  # Allow unfree packages like Steam

  # DO NOT CHANGE **YOUR** DEFAULT VALUE HERE UNLESS YOU KNOW WHAT YOU ARE DOING 
  # For more information see https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
