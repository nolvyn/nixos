{ den, ... }:
{
  # Cross-platform personal workstation applications. This is intentionally
  # opt-in so future servers do not inherit GUI applications, gaming, AI tools,
  # or personal persistence declarations accidentally.
  den.aspects.workstation = {
    includes = with den.aspects; [
      ai.antigravity
      ai.chatgpt
      ai.claude
      ai.cursor
      ai.general
      ai.opencode
      base
      browser
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
