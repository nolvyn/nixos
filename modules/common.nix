{ den, ... }:
{
  den.aspects.common = {
    includes = with den.aspects; [
      agenix
      ai.antigravity
      ai.chatgpt
      ai.claude
      ai.cursor
      ai.general
      ai.opencode
      audio
      bluetooth
      browser
      btop
      btrfs
      cache
      dev
      disko
      fastfetch
      file
      fish
      fonts
      gaming
      ghostty
      git
      hyprland
      impermanence
      keyboard
      kitty
      locale
      localsend
      optimizations
      proton
      rofi
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
          brightnessctl
          celluloid
          dunst
          glib
          lynis
          nautilus
          networkmanagerapplet
          onlyoffice-desktopeditors
          playerctl
          resources
        ];

      };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        exiftool
        file
        unstable.filen-desktop
        gzip
        jq
        mediainfo
        ripgrep
        ripunzip
        sherlock
        slack
        spotify
        tree
        unrar
        wget
      ];
    };
  };
}
