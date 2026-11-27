{ den, ... }:
{
  # Opt-in cross-platform personal workstation profile. Keeps GUI apps, gaming, AI tools and
  # personal persistence off future servers by default.
  den.aspects.workstation = {
    includes = with den.aspects; [
      ai.antigravity
      ai.chatgpt
      ai.claude
      ai.general
      ai.grok
      ai.muse
      ai.opencode
      ai.paseo
      base
      browser
      celluloid
      dev
      fish
      fonts
      gaming
      localsend
      proton
      spotify
      vesktop
      vscode
    ];

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          nautilus
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
          tree
          unrar
          wget
        ];
      };
  };
}
