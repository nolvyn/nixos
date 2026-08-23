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
        homeManagerTrampolines = "${config.home.homeDirectory}/Applications/Home Manager Trampolines";
        trampolineCache = "${config.xdg.cacheHome}/mac-app-util";
        macAppUtil = inputs.mac-app-util.packages.${pkgs.stdenv.hostPlatform.system}.default;
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

        # mac-app-util's direct generation can race Spotlight on macOS Tahoe
        # while an AppleScript app bundle is still being populated. Keep the
        # upstream generator and Dock synchronization, but expose only a
        # complete replacement directory.
        home.activation.trampolineApps = lib.mkIf isDarwin (
          lib.mkForce (
            lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
              (
              sourceDir=${lib.escapeShellArg homeManagerApps}
              finalDir=${lib.escapeShellArg homeManagerTrampolines}
              workDir=${lib.escapeShellArg trampolineCache}
              macAppUtil=${lib.escapeShellArg "${macAppUtil}/bin/mac-app-util"}
              tempDir=""
              backupDir=""
              backupCreated=0
              replacementStarted=0

              cleanup() {
                status=$?
                trap - EXIT

                if (( status != 0 )); then
                  if (( replacementStarted == 1 )); then
                    /bin/rm -rf "$finalDir" || true
                    if (( backupCreated == 1 )) && [[ -e "$backupDir" || -L "$backupDir" ]]; then
                      if /bin/mv "$backupDir" "$finalDir"; then
                        backupCreated=0
                      else
                        printf >&2 'error: could not restore the previous trampoline directory: %s\n' "$finalDir"
                      fi
                    fi
                  fi
                elif (( backupCreated == 1 )) && [[ -e "$backupDir" || -L "$backupDir" ]]; then
                  if ! /bin/rm -rf "$backupDir"; then
                    printf >&2 'error: could not remove the previous trampoline backup: %s\n' "$backupDir"
                    status=1
                  else
                    backupCreated=0
                  fi
                fi

                if [[ -n "$tempDir" && ( -e "$tempDir" || -L "$tempDir" ) ]]; then
                  /bin/rm -rf "$tempDir"
                fi

                exit "$status"
              }
              trap cleanup EXIT

              if [[ -v DRY_RUN ]]; then
                verboseEcho "Would rebuild mac-app-util trampolines in a private cache directory"
                exit 0
              fi

              if [[ ! -L "$sourceDir" ]]; then
                printf >&2 'error: expected Home Manager Apps to be a linkApps symlink: %s\n' "$sourceDir"
                exit 1
              fi

              if ! /bin/mkdir -p "$workDir"; then
                printf >&2 'error: could not create private mac-app-util cache directory: %s\n' "$workDir"
                exit 1
              fi

              if ! tempDir=$(/usr/bin/mktemp -d "$workDir/Home Manager Trampolines.XXXXXX"); then
                printf >&2 'error: could not create a private mac-app-util trampoline directory\n'
                exit 1
              fi

              backupDir="$workDir/Home Manager Trampolines.backup.$$"
              if [[ -e "$backupDir" || -L "$backupDir" ]]; then
                printf >&2 'error: refusing to overwrite an existing mac-app-util backup path: %s\n' "$backupDir"
                exit 1
              fi

              if ! run "$macAppUtil" sync-trampolines "$sourceDir" "$tempDir"; then
                printf >&2 'error: mac-app-util trampoline generation failed; preserving %s\n' "$finalDir"
                exit 1
              fi

              shopt -s nullglob
              sourceApps=( "$sourceDir"/*.app "$sourceDir"/*/*.app )
              tempApps=( "$tempDir"/*.app "$tempDir"/*/*.app )
              if (( ''${#sourceApps[@]} != ''${#tempApps[@]} )); then
                printf >&2 'error: mac-app-util generated an incomplete trampoline set; preserving %s\n' "$finalDir"
                exit 1
              fi

              for app in "''${tempApps[@]}"; do
                if [[ ! -d "$app" || ! -f "$app/Contents/Info.plist" ]]; then
                  printf >&2 'error: mac-app-util generated an incomplete app bundle: %s\n' "$app"
                  exit 1
                fi
              done

              if [[ -L "$finalDir" || -d "$finalDir" ]]; then
                if ! /bin/mv "$finalDir" "$backupDir"; then
                  printf >&2 'error: could not stage the previous trampoline directory: %s\n' "$finalDir"
                  exit 1
                fi
                backupCreated=1
              elif [[ -e "$finalDir" ]]; then
                printf >&2 'error: refusing to replace non-directory trampoline target: %s\n' "$finalDir"
                exit 1
              fi

              replacementStarted=1
              if ! /bin/mv "$tempDir" "$finalDir"; then
                printf >&2 'error: could not expose the completed trampoline directory: %s\n' "$finalDir"
                exit 1
              fi
              tempDir=""

              finalApps=( "$finalDir"/*.app "$finalDir"/*/*.app )
              for app in "''${finalApps[@]}"; do
                if ! run /usr/bin/touch "$app"; then
                  printf >&2 'error: could not refresh the visible trampoline bundle: %s\n' "$app"
                  exit 1
                fi
              done

              if (( backupCreated == 1 )); then
                if ! /bin/rm -rf "$backupDir"; then
                  printf >&2 'error: could not remove the previous trampoline backup: %s\n' "$backupDir"
                  exit 1
                fi
                backupCreated=0
              fi
              )
            ''
          )
        );

        # Migrate the directory created by the old copyApps target. The
        # validation is intentionally limited to generated app bundles and
        # Finder metadata before removing anything.
        home.activation.migrateCopiedApps = lib.mkIf isDarwin (
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
            appsDir=${lib.escapeShellArg homeManagerApps}

            if [[ -L "$appsDir" || ! -e "$appsDir" ]]; then
              :
            elif [[ ! -d "$appsDir" ]]; then
              printf >&2 'error: refusing to replace non-directory Home Manager Apps target: %s\n' "$appsDir"
              exit 1
            else
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
                    if [[ ! -d "$entry" || -L "$entry" || ! -f "$entry/Contents/Info.plist" ]]; then
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
            fi
          ''
        );
      };
  };
}
