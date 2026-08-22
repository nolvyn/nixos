# Enable fish and configure it for interactive use.
{ lib, ... }:
{
  den.aspects.fish = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".local/share/fish"
        ];
      };

    darwin =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      let
        dsclUser = lib.escapeShellArg "/Users/${host.userName}";
      in
      {
        # Den v0.18 registers the shell for nix-darwin but does not yet add it
        # to environment.shells. Keep the shell path stable across upgrades.
        environment.shells = [ pkgs.fish ];

        # Existing macOS accounts are Directory Services-owned. nix-darwin
        # intentionally does not mutate their UserShell, so reconcile it at
        # activation time after /etc/shells has been generated.
        system.activationScripts.postActivation.text = lib.mkAfter ''
          desiredShell="/run/current-system/sw/bin/fish"

          if ! currentShell=$(/usr/bin/dscl . -read ${dsclUser} UserShell 2>/dev/null | /usr/bin/sed -n 's/^UserShell: //p'); then
            printf >&2 'error: could not read UserShell for ${dsclUser}\n'
            exit 1
          fi

          if [[ -z "$currentShell" ]]; then
            printf >&2 'error: UserShell for ${dsclUser} is empty; refusing to change it\n'
            exit 1
          fi

          if [[ "$currentShell" != "$desiredShell" ]]; then
            if ! /usr/bin/grep -Fxq "$desiredShell" /etc/shells; then
              printf >&2 'error: refusing to set %s as the login shell because it is not registered in /etc/shells\n' "$desiredShell"
              exit 1
            fi

            printf >&2 'setting UserShell for ${dsclUser} to %s\n' "$desiredShell"
            if ! /usr/bin/dscl . -create ${dsclUser} UserShell "$desiredShell"; then
              printf >&2 'error: failed to set UserShell for ${dsclUser}\n'
              exit 1
            fi
          fi
        '';
      };

    homeManager =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        linuxAliases = lib.optionalAttrs (lib.hasSuffix "linux" host.system) {
          nhs = "nh os switch";
          sure = "sudo reboot";
          rup = "ripunzip unzip-file";
          matu = "matugen image --source-color-index 0";
          oc = "opencode";
        };
      in
      {
        home.sessionVariables = {
          EDITOR = "nano -L";
          GOPATH = "${config.home.homeDirectory}/.local/share/go";
        };

        home.sessionPath = [ "${config.home.homeDirectory}/.local/share/go/bin" ];

        home.packages = [ pkgs.grc ];

        programs.fish = {
          interactiveShellInit = "set fish_greeting";
          shellAliases = {
            nfu = "cd $HOME/nixos && nix run .#write-flake && nix flake update";
            nfw = "cd $HOME/nixos && nix run .#write-flake && nix flake check";

            ga = "cd $HOME/nixos && git add .";
            gc = "git commit -m";
            gp = "git push origin main";
          }
          // linuxAliases;

          plugins = [
            {
              name = "grc";
              src = pkgs.fishPlugins.grc.src;
            }
          ];
        };
      };
  };
}
