{ den, ... }:
{
  den.hosts.aarch64-darwin.Astraeus = {
    hostName = "Astraeus";
    userName = "nolan";
    isLaptop = true;
    users.nolan = { };
  };

  den.aspects.Astraeus = {
    includes = with den.aspects; [
      determinate
      fish
      git
      dev
      macAppUtil
      fonts
      btop
      fastfetch
      yazi
      kitty
      zed
      vscode
      ai.general
      ai.codex
      ai.claude
      ai.opencode
    ];

    darwin = { host, ... }: {
      networking.computerName = host.hostName;
    };
  };
}
