{ inputs, ... }:
let
  mkMacAppUtil =
    let
      mkPackage =
        system:
        let
          modernPkgs = import inputs.unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        modernPkgs.stdenv.mkDerivation {
          pname = "mac-app-util";
          version = "d90c36";
          dontUnpack = true;
          nativeBuildInputs = [ modernPkgs.makeBinaryWrapper ];
          installPhase = ''
            mkdir -p "$out/bin"
            makeWrapper ${
              modernPkgs.sbcl.withPackages (
                ps: with ps; [
                  alexandria
                  cl-interpol
                  cl-json
                  inferior-shell
                  str
                  trivia
                ]
              )
            }/bin/sbcl "$out/bin/mac-app-util" \
              --add-flags "--script ${inputs.mac-app-util}/main.lisp" \
              --prefix PATH : "${
                modernPkgs.lib.makeBinPath [
                  modernPkgs.dockutil
                  modernPkgs.rsync
                  modernPkgs.findutils
                  modernPkgs.jq
                ]
              }"
          '';
        };
      upstream = import "${inputs.mac-app-util}/flake.nix";
      upstreamOutputs = upstream.outputs {
        self = outputs;
        nixpkgs = inputs.unstable;
        flake-utils = inputs.mac-app-util.inputs.flake-utils;
        cl-nix-lite = inputs.mac-app-util.inputs.cl-nix-lite;
        treefmt-nix = inputs.mac-app-util.inputs.treefmt-nix;
      };
      packages = builtins.mapAttrs (
        system: systemPackages:
        systemPackages
        // {
          default = mkPackage system;
        }
      ) upstreamOutputs.packages;
      outputs = upstreamOutputs // {
        inherit packages;
      };
    in
    outputs;
in
{
  flake-file.inputs.mac-app-util = {
    url = "github:mcflis/mac-app-util/d90c36aaa2b35a4fe01edb77160574d0979f74a1";
    inputs.nixpkgs.follows = "unstable";
  };

  den.aspects.macAppUtil = {
    darwin = {
      imports = [ mkMacAppUtil.darwinModules.default ];
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
        imports = [ mkMacAppUtil.homeManagerModules.default ];

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
