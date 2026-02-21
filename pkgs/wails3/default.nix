{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  go,
  nodejs,
  zlib,
  nix-update-script,
  # Linux specific dependencies
  gtk3,
  webkitgtk_4_1,
}:

buildGoModule rec {
  pname = "wails3";
  version = "3.0.0-alpha.71";

  src = fetchFromGitHub {
    owner = "wailsapp";
    repo = "wails";
    tag = "v${version}";
    hash = "sha256-5lkXG25Lg1LTp4VPQuiuFj6Aq/8lirhScOONF3tulXw=";
  };

  sourceRoot = "${src.name}/v3";

  vendorHash = "sha256-6nuopdlOLidZUCFVcTl+9Jz8H0zhFJHIm5VDRqo0gGg=";

  proxyVendor = true;

  subPackages = [ "cmd/wails3" ];

  # These packages are needed to build wails
  # and will also need to be used when building a wails app.
  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  # Wails apps are built with Go, so we need to be able to
  # add it in propagatedBuildInputs.
  allowGoReference = true;

  # Following packages are required when wails used as a builder.
  propagatedBuildInputs = [
    pkg-config
    go
    stdenv.cc
    nodejs
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    gtk3
    webkitgtk_4_1
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  # As Wails calls a compiler, certain apps and libraries need to be made available.
  postFixup = ''
    wrapProgram $out/bin/wails3 \
      --prefix PATH : ${
        lib.makeBinPath [
          pkg-config
          go
          stdenv.cc
          nodejs
        ]
      } \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath (
          lib.optionals stdenv.hostPlatform.isLinux [
            gtk3
            webkitgtk_4_1
          ]
        )
      }" \
      --set PKG_CONFIG_PATH "$PKG_CONFIG_PATH" \
      --set CGO_LDFLAGS "-L${lib.makeLibraryPath [ zlib ]}"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Build desktop applications using Go & Web Technologies";
    homepage = "https://wails.io";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ nolvyn ];
    mainProgram = "wails3";
    platforms = lib.platforms.unix;
  };
}
