{ den, ... }:
{
  # Platform-neutral NixOS policy that does not itself select a desktop or
  # storage layout. The security and identity bundle below remains separate
  # because its current persistence declarations require nixosStorage.
  den.aspects.nixosBase = {
    includes = with den.aspects; [
      cache
      locale
      optimizations
    ];
  };

  # These aspects currently persist state under /persistent. Keep them out of
  # the generic base so a future server can choose a different storage policy.
  den.aspects.nixosSecurity = {
    includes = with den.aspects; [
      agenix
      security.general
      security.kernel
      security.network
      security.ssh
      security.systemd
      user
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.lynis ];
      };
  };

  # Current WeebMachine storage policy. This intentionally remains an explicit
  # profile because Disko and the rollback service assume its NVMe/LUKS/Btrfs
  # layout; it is not a generic NixOS server storage profile.
  den.aspects.nixosStorage = {
    includes = with den.aspects; [
      btrfs
      disko
      impermanence
    ];
  };

  # Linux desktop configuration can be reused by NixOS or standalone Linux
  # Home Manager. Its NixOS projection needs a storage profile because several
  # of the existing desktop aspects declare persistence under /persistent.
  den.aspects.linuxDesktop = {
    includes = with den.aspects; [
      audio
      bluetooth
      file
      fonts
      hyprland
      keyboard
      rofi
      sddm
      theme
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          brightnessctl
          dunst
          glib
          networkmanagerapplet
          playerctl
          resources
        ];
      };
  };

  # The complete current NixOS graphical-machine profile. Keep the storage
  # dependency visible here rather than making common imply it.
  den.aspects.nixosDesktop = {
    includes = with den.aspects; [
      linuxDesktop
      nixosBase
      nixosSecurity
      nixosStorage
    ];
  };

  # Cross-platform personal workstation applications. The NixOS projection is
  # intentionally opt-in so future servers do not inherit GUI applications,
  # gaming, AI tools, or personal persistence declarations accidentally.
  den.aspects.workstation = {
    includes = with den.aspects; [
      ai.antigravity
      ai.chatgpt
      ai.claude
      ai.cursor
      ai.general
      ai.opencode
      browser
      common
      dev
      fish
      fonts
      gaming
      localsend
      proton
      vesktop
      vscode
      zed
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          celluloid
          nautilus
          onlyoffice-desktopeditors
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          exiftool
          file
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
          unstable.filen-desktop
          wget
        ];
      };
  };
}
