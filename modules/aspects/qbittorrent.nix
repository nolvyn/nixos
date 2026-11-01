{ ... }:
{
  den.aspects.qbittorrent = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        "torrents"
        ".config/qBittorrent"
        ".local/share/qBittorrent"
      ];

      environment.systemPackages = with pkgs; [
        qbittorrent
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
            cfg = config.programs.qbittorrentConfinement;
            package = pkgs.qbittorrent;
            launcher = pkgs.writeShellScriptBin "qbittorrent" ''
              exec "${pkgs.apparmor-bin-utils}/bin/aa-exec" -p nixos-qbittorrent -- "${package}/bin/qbittorrent" "$@"
            '';
            guardedDesktop = pkgs.runCommand "qbt-guard-${package.version}" { } ''
              mkdir -p "$out/bin" "$out/share/applications"
              ln -s "${launcher}/bin/qbittorrent" "$out/bin/qbittorrent"
              substitute "${package}/share/applications/org.qbittorrent.qBittorrent.desktop" \
                "$out/share/applications/org.qbittorrent.qBittorrent.desktop" \
                --replace-fail "Exec=qbittorrent" "Exec=${launcher}/bin/qbittorrent"
            '';
            userHome = config.users.users.${host.userName}.home;
            safePath =
              path:
              lib.hasPrefix "/" path
              && path != "/"
              && !lib.hasInfix "//" path
              && builtins.match "/[A-Za-z0-9._ /+-]+" path != null
              && lib.all (part: part != "." && part != "..") (lib.splitString "/" path)
              && !lib.hasSuffix "/" path;
            literalPath = lib.types.addCheck lib.types.str safePath;
            runtimeRoots = [
              package
            ]
            ++ lib.optional cfg.enableSearch pkgs.python3
            ++ config.fonts.packages
            ++ config.fonts.fontconfig.confPackages
            ++ lib.optional config.hardware.graphics.enable config.hardware.graphics.package;
            runtimeRules = pkgs.apparmorRulesFromClosure {
              name = "qbittorrent-runtime";
              # Read/map only the selected runtime closure; do not grant execution.
              baseRules = [
                "$path/ r"
                "$path/** mr"
              ];
            } runtimeRoots;
            etcFiles = [
              "group"
              "host.conf"
              "hosts"
              "localtime"
              "machine-id"
              "nsswitch.conf"
              "passwd"
              "resolv.conf"
              "ssl/certs/ca-certificates.crt"
              "ssl/openssl.cnf"
            ];
            resolvedEtcRules = lib.concatMapStringsSep "\n" (
              name:
              lib.optionalString (builtins.hasAttr name config.environment.etc) ''"${
                config.environment.etc.${name}.source
              }" r,''
            ) etcFiles;
            directoryRules =
              lib.concatMapStringsSep "\n"
                (path: ''
                  owner "${path}/" rw,
                  owner "${path}/**" rwkl,
                '')
                (
                  cfg.downloadDirectories
                  ++ [
                    "${userHome}/.cache/qBittorrent"
                    "${userHome}/.config/qBittorrent"
                    "${userHome}/.local/share/qBittorrent"
                  ]
                );
          in
          {
            options.programs.qbittorrentConfinement = {
              enable = lib.mkEnableOption "the qBittorrent file-access profile";
              downloadDirectories = lib.mkOption {
                type = lib.types.listOf literalPath;
                default = [ "${userHome}/torrents" ];
                description = "Literal approved download directories; other destinations are denied. Home/legacy .Private exclusions always take precedence, even inside a declared download tree.";
              };
              enableSearch = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Permit the selected Python interpreter to execute with inherited confinement for qBittorrent search plugins.";
              };
            };

            config = lib.mkIf cfg.enable {
              assertions = [
                {
                  assertion = config.security.apparmor.enable;
                  message = "qBittorrent confinement requires AppArmor.";
                }
                {
                  assertion = safePath userHome && cfg.downloadDirectories != [ ];
                  message = "qBittorrent confinement requires a literal home and at least one approved download directory.";
                }
              ];

              security.apparmor.policies.nixos-qbittorrent = {
                state = "enforce";
                profile = ''
                  abi <abi/4.0>,
                  include <tunables/global>

                  # Attach before either the packaged ELF wrapper or its real binary runs.
                  # Retained package paths also attach. Compatibility with runtime
                  # dependencies outside the selected closure is not guaranteed.
                  profile nixos-qbittorrent "/nix/store/*-qbittorrent-*/bin/{qbittorrent,.qbittorrent-wrapped}" flags=(attach_disconnected,mediate_deleted) {
                    include <abstractions/base>
                    include <abstractions/fonts>
                    include <abstractions/nameservice-strict>
                    include "${runtimeRules}"

                    # The base abstraction assumes these eCryptfs locations contain
                    # encrypted data and grants broad file/execute access. Reserve
                    # them regardless of downloadDirectories; names prove nothing.
                    deny @{HOME}/.Private/{,**} mrwklx,
                    deny @{HOMEDIRS}/.ecryptfs/*/.Private/{,**} mrwklx,

                    "${package}/bin/qbittorrent" rix,
                    "${package}/bin/.qbittorrent-wrapped" rix,
                    ${lib.optionalString cfg.enableSearch ''
                      "${pkgs.python3}/bin/python3" rix,
                      "${pkgs.python3}/bin/${pkgs.python3.executable}" rix,
                      owner /dev/shm/sem.* rwkl,
                      owner /tmp/pymp-*/ rw,
                      owner /tmp/pymp-*/** rwkl,
                    ''}

                    owner "${userHome}/" r,
                    ${directoryRules}
                    ${resolvedEtcRules}

                    # Pathname Unix sockets use file rules; do not grant blanket Unix access.
                    # Qt's single-instance socket and short-lived app files.
                    owner /tmp/.qBittorrent/ rw,
                    owner /tmp/.qBittorrent/** rwkl,
                    owner /run/user/[0-9]*/wayland-[0-9]* rw,
                    /etc/ssl/ r,
                    /etc/ssl/certs/ r,
                    /etc/host.conf r,
                    # Local socket paths are not an IPC boundary on kernels lacking
                    # fine AF_UNIX mediation; this policy promises direct file access only.
                    /run/nscd/socket rw,
                    /run/systemd/resolve/io.systemd.Resolve rw,


                    owner @{PROC}/[0-9]*/attr/current r,
                    owner @{PROC}/[0-9]*/mountinfo r,
                    @{PROC}/sys/kernel/random/boot_id r,
                    /sys/block/ r,
                    /sys/devices/**/block/*/dev r,
                    /sys/devices/**/block/*/queue/rotational r,
                    /sys/devices/system/cpu/** r,

                    # Peer TCP/uTP, DNS and interface queries; no raw IP or net_admin.
                    network inet stream,
                    network inet6 stream,
                    network inet dgram,
                    network inet6 dgram,
                    network netlink dgram,
                    # NETLINK_ROUTE monitoring uses SOCK_RAW; this is not raw IP.
                    network netlink raw,
                  }
                '';
              };

              # The normal desktop/PATH launch fails if the named profile is unavailable.
              environment.systemPackages = [ (lib.hiPrio guardedDesktop) ];

              # NixOS's AppArmor module owns loading, boot ordering and reload triggers.
              # No application service, login hook, state rewrite or automatic restart.
            };
          }
        )
      ];
    };
  };
}
