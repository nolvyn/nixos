{ ... }:
{
  den.aspects.celluloid = {
    nixos =
      { host, config, ... }:
      {
        environment.systemPackages = [ config.programs.celluloidConfinement.package ];
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/celluloid"
        ];

        # Optional confinement is part of the app module and defaults to disabled.
        imports = [
          (
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              cfg = config.programs.celluloidConfinement;
              userName = host.userName;
              mediaRoots = cfg.mediaDirectories;
              outputRoot = cfg.outputDirectory;
              allowInternet = cfg.enableStreaming;
              storeRoot =
                path:
                let
                  text = toString path;
                  root = builtins.head (builtins.match "(/nix/store/[^/]+).*" text);
                in
                builtins.appendContext root (builtins.getContext text);
              publicEtcRoots =
                lib.concatMap
                  (
                    name:
                    let
                      entry = config.environment.etc.${name} or null;
                      path = if entry == null then null else entry.source;
                    in
                    lib.optional (path != null && builtins.match "(/nix/store/[^/]+).*" (toString path) != null) (
                      storeRoot path
                    )
                  )
                  [
                    "os-release"
                    "hosts"
                    "nsswitch.conf"
                    "host.conf"
                    "gai.conf"
                    "services"
                    "protocols"
                  ];
              extraFontRoots =
                config.fonts.packages
                ++ lib.optional config.fonts.fontconfig.enable (storeRoot config.environment.etc.fonts.source)
                ++ publicEtcRoots
                ++ config.system.nssModules.list;
              helpers =
                lib.optionals allowInternet [
                  "${pkgs.yt-dlp}/bin/yt-dlp"
                  "${pkgs.yt-dlp}/bin/.yt-dlp-wrapped"
                  "${pkgs.python3}/bin/python${pkgs.python3.pythonVersion}"
                  pkgs.runtimeShell
                ]
                ++ map lib.getExe cfg.extraHelpers;
              safeDirectory =
                path:
                lib.hasPrefix "/" path
                && lib.all (segment: segment != "." && segment != "..") (lib.splitString "/" path)
                && !(builtins.elem path [
                  "/"
                  "/home"
                  home
                ])
                && !(lib.any (value: lib.hasInfix value path) [
                  "\""
                  "\\"
                  "\n"
                  "\r"
                  "*"
                  "?"
                  "["
                  "]"
                  "{"
                  "}"
                ]);
              temporaryDirectory = "${home}/.cache/celluloid/tmp";
              resumeDirectory = "${home}/.config/celluloid/watch_later";
              launcher =
                pkgs.runCommand "celluloid-confined-launcher-${pkgs.celluloid.version}"
                  { nativeBuildInputs = [ pkgs.python3 ]; }
                  ''
                        mkdir -p "$out/bin" "$out/share"
                        python3 - ${pkgs.celluloid}/share "$out/share" <<'COPY_SHARE'
                    import pathlib,shutil,sys
                    source,target=map(pathlib.Path,sys.argv[1:])
                    for entry in source.iterdir():
                        if entry.name == "dbus-1":
                            shutil.copytree(entry,target/entry.name,symlinks=True)
                        else:
                            (target/entry.name).symlink_to(entry)
                    COPY_SHARE
                        cat > "$out/bin/celluloid" <<'SH'
                    #!${pkgs.runtimeShell}
                    set -eu
                    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg temporaryDirectory} ${lib.escapeShellArg resumeDirectory} ${lib.escapeShellArg outputRoot}
                    export TMPDIR=${lib.escapeShellArg temporaryDirectory}
                    exec ${pkgs.apparmor-bin-utils}/bin/aa-exec -p nixos-celluloid -- ${pkgs.celluloid}/bin/celluloid --mpv-screenshot-template=celluloid-%f-%P --mpv-screenshot-format=png --mpv-ytdl-raw-options=yes-playlist=,ignore-config= --mpv-screenshot-directory=${lib.escapeShellArg outputRoot} --mpv-watch-later-directory=${lib.escapeShellArg resumeDirectory} "$@"
                    SH
                        chmod +x "$out/bin/celluloid"
                        service="$out/share/dbus-1/services/io.github.celluloid_player.Celluloid.service"
                        chmod u+w "$service"
                        python3 - "$service" "$out/bin/celluloid" <<'PYTHON'
                    import pathlib,sys
                    path=pathlib.Path(sys.argv[1]);text=path.read_text();old="${pkgs.celluloid}/bin/celluloid"
                    assert text.count(old)==1, "Review changed Celluloid D-Bus activation entry"
                    path.write_text(text.replace(old,sys.argv[2]))
                    PYTHON
                  '';
              home = "/home/${userName}";
              quote = value: ''"${value}"'';
              closure = pkgs.closureInfo {
                rootPaths = [
                  pkgs.celluloid
                  pkgs.mesa
                  pkgs.hicolor-icon-theme
                ]
                ++ extraFontRoots
                ++ lib.optionals allowInternet [
                  pkgs.yt-dlp
                  pkgs.python3
                  pkgs.bash
                  pkgs.cacert
                ]
                ++ cfg.extraHelpers;
              };
              closureRules = pkgs.runCommand "celluloid-reviewed-closure-rules" { } ''
                while IFS= read -r path; do
                  printf '"%s" r,\n"%s/" r,\n"%s/**" mr,\n' "$path" "$path" "$path"
                done < ${closure}/store-paths > "$out"
              '';
              filteredBase =
                pkgs.runCommand "celluloid-private-safe-base" { nativeBuildInputs = [ pkgs.python3 ]; }
                  ''
                        python3 - ${pkgs.apparmor-profiles}/etc/apparmor.d/abstractions/base "$out" <<'PY'
                    import pathlib,sys
                    text=pathlib.Path(sys.argv[1]).read_text()
                    for rule in [
                     '  owner @{HOME}/.Private/ r,',
                     '  owner @{HOME}/.Private/** mrixwlk,',
                     '  owner @{HOMEDIRS}/.ecryptfs/*/.Private/ r,',
                     '  owner @{HOMEDIRS}/.ecryptfs/*/.Private/** mrixwlk,',
                    ]:
                        assert text.count(rule)==1, 'Review changed upstream base abstraction: '+rule
                        text=text.replace(rule, '# Removed broad private-directory grant for this candidate only')
                    pathlib.Path(sys.argv[2]).write_text(text)
                    PY
                  '';
              readMedia = lib.concatMapStringsSep "\n" (root: ''
                ${quote "${root}/"} r,
                ${quote "${root}/**"} r,
              '') mediaRoots;
              helperRules = lib.concatMapStringsSep "\n" (helper: "${quote helper} ix,") helpers;
            in
            {
              options.programs.celluloidConfinement = {
                enable = lib.mkEnableOption "opt-in Celluloid direct-file confinement";
                mediaDirectories = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "${home}/Downloads"
                    "${home}/torrents"
                  ];
                  description = "Readable media/subtitle/playlist roots; filename permissions do not distinguish sensitive content.";
                };
                outputDirectory = lib.mkOption {
                  type = lib.types.str;
                  default = "${home}/Downloads";
                  description = "Screenshot destination; only direct child celluloid-*.png names are writable, including pre-existing matching files.";
                };
                enableStreaming = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Retain Internet playback and the packaged yt-dlp helper under inherited confinement.";
                };
                extraHelpers = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                  description = "Individually reviewed extra script helpers; executables inherit the same file boundary.";
                };
                package = lib.mkOption {
                  type = lib.types.package;
                  readOnly = true;
                  default = if cfg.enable then launcher else pkgs.celluloid;
                  description = "The unchanged upstream package while disabled, otherwise the scoped launcher.";
                };
              };
              config = lib.mkIf cfg.enable {
                assertions = [
                  {
                    assertion = config.security.apparmor.enable;
                    message = "Celluloid confinement requires AppArmor";
                  }
                  {
                    assertion = mediaRoots != [ ];
                    message = "Choose Celluloid mediaDirectories before enabling confinement";
                  }
                  {
                    assertion = lib.all safeDirectory (mediaRoots ++ [ outputRoot ]);
                    message = "Use explicit literal absolute media/output directories, not home/root or glob patterns";
                  }

                  {
                    assertion = pkgs.celluloid.version == "0.30";
                    message = "Requalify Celluloid confinement after changing its executable/helper contract";
                  }
                  {
                    assertion = config.boot.kernelPackages.kernel.version == "7.2.11";
                    message = "Requalify Celluloid confinement on the selected kernel";
                  }
                ];
                security.apparmor.policies.nixos-celluloid = {
                  state = "enforce";
                  profile = ''
                    abi <abi/4.0>,
                    include <tunables/global>
                    profile nixos-celluloid "${pkgs.celluloid}/bin/{celluloid,.celluloid-wrapped}" flags=(attach_disconnected) {
                      include "${filteredBase}"
                      include <abstractions/fonts>
                      include "${closureRules}"
                      # Coarse Unix access is retained for desktop use. No fine socket isolation
                      # is claimed for the selected parser/kernel/bus stack.
                      network unix,
                      ${lib.optionalString allowInternet ''
                          network inet stream,
                          network inet6 stream,
                          network inet dgram,
                          network inet6 dgram,
                          /etc/resolv.conf r,
                        /etc/{host.conf,gai.conf,services,protocols} r,
                        /run/NetworkManager/resolv.conf r,
                        /run/systemd/resolve/{resolv.conf,stub-resolv.conf} r,
                        /run/{.nscd_socket,nscd/socket} rw,
                        /{var/db,var/cache,var/lib,run}/nscd/{passwd,group,services,hosts} mr,
                        /run/nscd/db* mr,
                          /etc/ssl/certs/** r,
                      ''}
                      # Intended D-Bus policy: current guest tests did NOT prove enforcement.
                      dbus (send) bus=session path=/org/freedesktop/DBus interface=org.freedesktop.DBus
                        member={Hello,AddMatch,RemoveMatch,GetNameOwner,NameHasOwner,StartServiceByName,ListNames,RequestName,ReleaseName,GetConnectionUnixProcessID}
                        peer=(name=org.freedesktop.DBus),
                      dbus (bind) bus=session name=io.github.celluloid_player.Celluloid,
                      dbus (bind) bus=session name=org.mpris.MediaPlayer2.io.github.celluloid_player.Celluloid*,
                      dbus (receive) bus=session,
                      dbus (send) bus=session peer=(name=ca.desrt.dconf),
                      "${pkgs.celluloid}/bin/celluloid" ix,
                      "${pkgs.celluloid}/bin/.celluloid-wrapped" ix,
                      ${helperRules}
                      ${lib.optionalString allowInternet ''
                        "${home}/.cache/yt-dlp/" rw,
                        "${home}/.cache/yt-dlp/**" rwk,
                      ''}
                      /etc/{passwd,group,nsswitch.conf,hosts,machine-id,os-release} r,
                      # Only directory traversal through the selected merged icon tree;
                      # icon file targets still need their own reviewed closure grants.
                      "${config.system.path}/share/icons/" r,
                      "${config.system.path}/share/icons/**/" r,
                      "${config.system.path}/share/pixmaps/" r,
                      /etc/fonts/** r,
                      /etc/xdg/** r,
                      /run/mount/utab r,
                      /dev/dri/ r,
                      /proc/{meminfo,cpuinfo,stat,filesystems} r,
                      /proc/[0-9]*/{maps,status,auxv,mountinfo,stat} r,
                      /sys/devices/system/node/ r,
                      /sys/devices/system/{cpu,node}/** r,
                      ${lib.optionalString (config.i18n.glibcLocales != null) ''
                        "${config.i18n.glibcLocales}/lib/locale/locale-archive" mr,
                      ''}
                      /sys/kernel/mm/transparent_hugepage/** r,
                      "${home}/" r,
                      "${home}/.config/" r,
                      "${home}/.config/celluloid/" r,
                      "${home}/.config/celluloid/watch_later/" rw,
                      "${home}/.config/celluloid/watch_later/**" rwk,
                      "${home}/.config/dconf/user" r,
                      "${home}/.cache/" r,
                      "${home}/.cache/celluloid/" rw,
                      "${home}/.cache/celluloid/**" rwkl,
                      "${home}/.cache/fontconfig/" rw,
                      "${home}/.cache/fontconfig/**" rwkl,
                      "${home}/.cache/mesa_shader_cache*/" rw,
                      "${home}/.cache/mesa_shader_cache*/**" rwkl,
                      owner /run/user/[0-9]*/{bus,wayland-*,pipewire-*,pulse/native} rw,
                      owner /run/user/[0-9]*/dconf/ rw,
                      owner /run/user/[0-9]*/dconf/user rw,
                      ${readMedia}
                      ${quote "${outputRoot}/"} r,
                      ${quote "${outputRoot}/celluloid-*.png"} rwk,
                    }
                  '';
                };
              };
            }
          )
        ];
      };
  };
}
