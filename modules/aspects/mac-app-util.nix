{ inputs, ... }:
{
  flake-file.inputs.mac-app-util.url = "github:hraban/mac-app-util";

  den.aspects.macAppUtil = {
    darwin = {
      imports = [ inputs.mac-app-util.darwinModules.default ];
      services.mac-app-util.enable = true;
    };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
        homeManagerApps = "${config.home.homeDirectory}/Applications/Home Manager Apps";
      in
      {
        imports = [ inputs.mac-app-util.homeManagerModules.default ];

        targets.darwin = lib.mkIf isDarwin {
          "mac-app-util".enable = true;
          copyApps.enable = false;
          linkApps.enable = true;
        };

        # linkApps owns this directory, but Home Manager's collision check runs
        # before activation can remove the directory left by copyApps.
        home.file."Applications/Home Manager Apps".force = lib.mkIf isDarwin true;

        # Migrate the directory created by the old copyApps target. The
        # validation is intentionally limited to generated app bundles and
        # Finder metadata before removing anything.
        home.activation.migrateCopiedApps = lib.mkIf isDarwin (
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
            appsDir=${lib.escapeShellArg homeManagerApps}

            if [[ -L "$appsDir" || ! -e "$appsDir" ]]; then
              exit 0
            fi

            if [[ ! -d "$appsDir" ]]; then
              printf >&2 'error: refusing to replace non-directory Home Manager Apps target: %s\n' "$appsDir"
              exit 1
            fi

            shopt -s dotglob nullglob
            appEntries=( "$appsDir"/* )
            for entry in "''${appEntries[@]}"; do
              name="''${entry##*/}"
              case "$name" in
                .DS_Store)
                  if [[ ! -f "$entry" ]]; then
                    printf >&2 'error: refusing to remove unexpected Home Manager Apps entry: %s\n' "$entry"
                    exit 1
                  fi
                  ;;
                *.app)
                  if [[ ! -d "$entry" || -L "$entry" ]]; then
                    printf >&2 'error: refusing to remove unexpected Home Manager Apps entry: %s\n' "$entry"
                    exit 1
                  fi
                  ;;
                *)
                  printf >&2 'error: refusing to remove unexpected Home Manager Apps entry: %s\n' "$entry"
                  exit 1
                  ;;
              esac
            done

            run /bin/rm -rf "$appsDir"
          ''
        );
      };
  };
}
