{ den, inputs, ... }:
{
  den.hosts.aarch64-darwin.Astraeus = {
    hostName = "Astraeus";
    userName = "nolan";
    users.nolan = { };
  };

  den.aspects.Astraeus = {
    includes = with den.aspects; [
      workstation
      determinate
      homebrew
      macAppUtil
      omniwm
    ];

    darwin =
      { host, lib, ... }:
      let
        masModule = builtins.readFile "${inputs.darwin}/modules/programs/mas.nix";
        masIdGuard = ''[[ -n "$id" ]]'';
      in
      {
        # Upstream merges mas warnings into its app list; accept only real app IDs.
        disabledModules = [ "${inputs.darwin}/modules/programs/mas.nix" ];
        imports = [
          (
            assert lib.hasInfix masIdGuard masModule;
            builtins.toFile "mas-validated-list.nix" (
              builtins.replaceStrings [ masIdGuard ] [ ''[[ "$id" =~ ^[1-9][0-9]*$ ]]'' ] masModule
            )
          )
        ];

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
