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
      common
      determinate
      homebrew
      macAppUtil
      omniwm
    ];

    darwin = { host, ... }: {
      networking.computerName = host.hostName;

      system.defaults.dock = {
        autohide = true;
        show-recents = false;
        persistent-apps = [
          { app = "/System/Applications/App Store.app"; }
          { app = "/System/Applications/Apps.app"; }
          { app = "/Users/${host.userName}/Applications/Home Manager Apps/Brave Browser.app"; }
          { app = "/Applications/ChatGPT.app"; }
          { app = "/Users/${host.userName}/Applications/Home Manager Apps/Kitty.app"; }
          { app = "/System/Applications/Messages.app"; }
          { app = "/System/Applications/Phone.app"; }
          { app = "/Users/${host.userName}/Applications/Home Manager Apps/Slack.app"; }
          { app = "/Users/${host.userName}/Applications/Home Manager Apps/Spotify.app"; }
          { app = "/System/Applications/System Settings.app"; }
          { app = "/Users/${host.userName}/Applications/Home Manager Apps/Visual Studio Code.app"; }
        ];
      };

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
