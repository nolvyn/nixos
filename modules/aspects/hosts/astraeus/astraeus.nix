{ den, inputs, ... }:
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
      homebrew
      omniwm
      fish
      git
      dev
      portableApps
      browser
      localsend
      vesktop
      ghostty
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
      ai.cursor
      ai.antigravity
    ];

    darwin = { host, ... }: {
      networking.computerName = host.hostName;

      programs.mas = {
        enable = true;
        packages = { };
        cleanup = true;
        update = false;
      };
    };

    # Home Manager otherwise inherits nix-darwin's newer package source.
    homeManager = {
      _module.args.pkgsPath = inputs.nixpkgs;
    };
  };
}
