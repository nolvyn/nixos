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
        lib,
        pkgs,
        ...
      }:
      let
        isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      in
      {
        imports = [ mkMacAppUtil.homeManagerModules.default ];

        targets.darwin = lib.mkIf isDarwin {
          "mac-app-util".enable = true;
          copyApps.enable = false;
          linkApps.enable = true;
        };
      };
  };
}
