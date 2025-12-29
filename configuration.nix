# configuration.nix
{ pkgs, config, lib, inputs, ... }:

let 
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
in 

{
  imports = [
    ./system/audio.nix
    ./system/bluetooth.nix
    ./system/brave.nix
    ./system/btrfs.nix
    ./system/dev.nix
    ./system/file.nix
    ./system/firefox.nix
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
    brightnessctl         # Control screen brightness
    dunst                 # Notification popups
    exiftool              # Show metadata for media files
    fastfetch             # Show system info in terminal
    filen-desktop         # Cloud Storage App
    ghostty               # Terminal Emulator
    kdePackages.dolphin   # File Manager
    kitty                 # Terminal Emulator
    lynis                 # System security checker
    mediainfo             # Show media file info
    networkmanagerapplet  # Wi-Fi/VPN tray icon
    onlyoffice-desktopeditors        # Office suite
    playerctl             # Control media players
    protonvpn-gui         # ProtonVPN desktop app
    quickshell
    resources             # Simple system monitor
    ripgrep               # Fast search in files
    ripunzip              # Extract zip files
    slack                 # Team chat app
    spotify               # Music streaming app
    tree                  # Show folder structure
    unrar
    vesktop               # Discord Client
    vlc
    walker
    waybar                # Status bar for Wayland
    wget                  # Download files from web
    yazi                  # Terminal File Manager
    zoom-us               # Video calls and meetings
  ];

  nixpkgs.config.allowUnfree = true;  # Allow unfree packages like Steam

  # DO NOT CHANGE **YOUR** DEFAULT VALUE HERE UNLESS YOU KNOW WHAT YOU ARE DOING 
  # For more information see https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
