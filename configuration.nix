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
    bibata-cursors
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
    resources             # Simple system monitor
    ripgrep               # Fast search in files
    ripunzip              # Extract zip files
    slack                 # Team chat app
    spotify               # Music streaming app
    tree                  # Show folder structure
    unrar
    vesktop               # Discord Client
    walker
    waybar                # Status bar for Wayland
    wget                  # Download files from web
    yazi                  # Terminal File Manager
    zoom-us               # Video calls and meetings

    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default # Quickshell
    vlc
    mpv
  ];

  # Define a user account. 
  users.users.${config.user.name} = {
    isNormalUser = true;
    extraGroups = [
      # "dialout"
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [];
  };

  hjem.users.${config.user.name} = {
    enable = true;
    clobberFiles = lib.mkForce true;
    files = {
      ".config/waybar/config".source = ./config/waybar/config;
      ".config/waybar/style.css".source = ./config/waybar/style.css;
      ".config/fuzzel/fuzzel.ini".source = ./config/fuzzel.ini;
      ".config/walker/init.txt".text = "";
      ".config/fastfetch/config.jsonc".source = ./config/fastfetch/config.jsonc;

      ".config/kitty/kitty.conf".source = ./config/kitty.conf;

      ".config/vesktop/settings.json".source = ./config/vesktop/vesktop-settings.json;
      ".config/vesktop/settings/settings.json".source = ./config/vesktop/vencord-settings.json;

    };
  };

  nixpkgs.config.allowUnfree = true;  # Allow unfree packages like Steam
}
