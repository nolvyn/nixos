# configuration.nix
{ pkgs, config, lib, inputs, ... }:

{
  imports = [
    ./system/audio.nix
    ./system/bluetooth.nix
    ./system/brave.nix
    ./system/btrfs.nix
    ./system/cache.nix
    ./system/dev.nix
    ./system/file.nix
    # ./system/firefox.nix
    ./system/fish.nix
    ./system/flatpak.nix
    ./system/fonts.nix
    ./system/git.nix
    ./config/hypr/hypr.nix
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

  environment.systemPackages = with pkgs; [
    anki
    brightnessctl
    celluloid
    dunst
    exiftool
    fastfetch
    file
    filen-desktop
    ghostty
    gzip
    kitty
    lynis
    mediainfo
    networkmanagerapplet
    onlyoffice-desktopeditors
    playerctl
    stable.protonvpn-gui
    quickshell
    resources
    ripgrep
    ripunzip
    slack
    spotify
    # spotify-player
    thunar
    tree
    unrar
    vesktop
    stable.walker
    waybar
    wget
    yazi
    zoom-us
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.nh = {
    enable = true;
    flake = "/home/weeb/nixos";
  };
  
  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;  # Allow closed source packages like Steam

  # DO NOT CHANGE THIS VALUE UNLESS YOU KNOW WHAT YOU ARE DOING 
  # For more information see https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
