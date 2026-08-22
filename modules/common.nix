{ den, ... }:
{
  den.aspects.common = {
    includes = with den.aspects; [
      agenix
      ai.antigravity
      ai.claude
      ai.codex
      ai.cursor
      ai.general
      ai.opencode
      audio
      bluetooth
      browser
      btrfs
      btop
      cache
      dev
      disko
      fastfetch
      file
      fish
      fonts
      git
      hyprland
      impermanence
      keyboard
      kitty
      locale
      localsend
      optimizations
      portableApps
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
      rofi
      vscode
      yazi
      zed
      ghostty
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          brightnessctl
          celluloid
          dunst
          glib
          lynis
          nautilus
          networkmanagerapplet
          onlyoffice-desktopeditors
          playerctl
          proton-vpn
          resources
        ];

      };
  };
}
