{ inputs, ... }:
{
  # Paseo v0.15.4. Keep its own nixpkgs pin: npm dependency hashes depend on it.
  flake-file.inputs.paseo.url = "github:getpaseo/paseo/1c00b365c9e0b74c1580eba33d905d693125ae21";

  den.aspects.ai.provides.paseo = {
    nixos =
      { config, host, ... }:
      {
        imports = [ inputs.paseo.nixosModules.default ];

        services.paseo = {
          enable = true;
          user = host.userName;
          group = config.users.users.${host.userName}.group;
          # Upstream keeps 127.0.0.1:6767, the firewall closed and user-profile PATH.
          # Do not use settings: its preStart overwrites mutable pairing/password config.
          environment = {
            # relay.enable alone only omits --no-relay; new homes opt out by default.
            PASEO_RELAY_ENABLED = "true";
            PASEO_WEB_UI_ENABLED = "true";
            # Blorf coordinator bridge (temporary, until Paseo is retired).
            PASEO_BLORF_BRIDGE_DIR = "/home/weeb/projects/business/.local/paseo-blorf-bridge";
            NODE_OPTIONS = "--import=/home/weeb/projects/business/shared/tools/paseo-blorf-loader.mjs";
          };
        };

        # Includes config, pairing identity, agent/session state, logs and worktrees.
        # Upstream creates this directory privately; follow normal persistence conventions.
        environment.persistence."/persistent".users.${host.userName}.directories = [ ".paseo" ];

        # Also order live switches after the persistent directory is mounted.
        systemd.services.paseo.unitConfig.RequiresMountsFor = [
          config.services.paseo.dataDir
        ];
      };

    darwin = {
      # Homebrew owns the desktop app and its bundled daemon; its native updater remains enabled.
      homebrew.casks = [ "paseo" ];
    };
  };
}
