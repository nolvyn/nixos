{ den, ... }:
{
  den.aspects.common = {
    includes = with den.aspects; [
      agenix
      audio
      bluetooth
      browser
      btrfs
      btop
      cache
      claude
      dev
      disko
      fastfetch
      file
      fish
      floorp
      fonts
      git
      hyprland
      impermanence
      keyboard
      kitty
      locale
      neovim
      optimizations
      sddm
      security.general
      security.kernel
      security.network
      security.ssh
      security.systemd
      syncthing
      theme
      user
      vesktop
      vscode
      yazi
      zed
    ];

    nixos =
      { pkgs, ... }:
      {
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
      };
  };
}
