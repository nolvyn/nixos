{ lib, ... }:
let
  browserExtensions = [
    "ponfpcnoihfmfllpaingbgckeeldkhle" # Enhancer for YouTube
    "gbefmodhlophhakmoecijeppjblibmie" # Linguist
    "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
  ];

  extensionInstallForcelist = map (
    id: "${id};https://clients2.google.com/service/update2/crx"
  ) browserExtensions;

  bravePolicies = {
    # Brave-Specific Policies
    BraveAIChatEnabled = false;
    BraveNewsDisabled = true;
    BraveP3AEnabled = false;
    BravePlaylistEnabled = false;
    BraveRewardsDisabled = true;
    BraveSpeedreaderEnabled = false;
    BraveStatsPingEnabled = false;
    BraveTalkDisabled = true;
    BraveVPNDisabled = true;
    BraveWalletDisabled = true;
    BraveWaybackMachineEnabled = false;
    BraveWebDiscoveryEnabled = false;
    TorDisabled = true;

    # Default Permission Settings (2 = Block)
    DefaultGeolocationSetting = 2;
    DefaultLocalFontsSetting = 2;
    DefaultNotificationsSetting = 2;
    DefaultSensorsSetting = 2;
    DefaultSerialGuardSetting = 2;

    # Reporting & Telemetry
    MetricsReportingEnabled = false;
    UrlKeyedAnonymizedDataCollectionEnabled = false;

    # Safe Browsing Features
    AlternateErrorPagesEnabled = false;
    SafeBrowsingDeepScanningEnabled = false;
    SafeBrowsingExtendedReportingEnabled = false;
    SafeBrowsingProtectionLevel = 1; # Standard Protection
    SafeBrowsingSurveysEnabled = false;

    # Autofill & Passwords
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    PasswordLeakDetectionEnabled = false;
    PasswordManagerEnabled = false;
    PasswordSharingEnabled = false;

    # Privacy & Security
    BlockThirdPartyCookies = true;
    EnableMediaRouter = false;
    ForceGoogleSafeSearch = false;
    HttpsOnlyMode = "force_enabled";
    ShoppingListEnabled = false;
    WebRtcIPHandling = "disable_non_proxied_udp";

    # Browser Behavior
    DefaultBrowserSettingEnabled = false;
    DesktopSharingHubEnabled = false;
    PromptForDownloadLocation = false;
    PromotionsEnabled = false;
    ShowCastIconInToolbar = false;
    SpellCheckServiceEnabled = false;
    ClearBrowsingDataOnExitList = [
      "autofill"
      "browsing_history"
      "download_history"
      "hosted_app_data"
      "password_signin"
    ];
  };

  darwinBravePolicies = bravePolicies // {
    ExtensionInstallForcelist = extensionInstallForcelist;
  };

  darwinChromePolicies = {
    ExtensionInstallForcelist = extensionInstallForcelist;
  };
in
{
  den.aspects.browser = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".pki"
        ".config/BraveSoftware"
        ".config/google-chrome"
      ];

      programs.chromium = {
        enable = true;
        extensions = browserExtensions;
        extraOpts = bravePolicies;
      };
    };

    darwin =
      { lib, pkgs, ... }:
      let
        policyDir = "/Library/Managed Preferences";
        policyFiles = {
          brave = "${policyDir}/com.brave.Browser.plist";
          chrome = "${policyDir}/com.google.Chrome.plist";
        };
        policyPlists = {
          brave = (pkgs.formats.plist { }).generate "com.brave.Browser.plist" darwinBravePolicies;
          chrome = (pkgs.formats.plist { }).generate "com.google.Chrome.plist" darwinChromePolicies;
        };
        mkPolicyReconciler =
          {
            name,
            policyFile,
            policyPlist,
          }:
          pkgs.writeShellScript "${name}-managed-policy-reconciler" ''
            set -eu

            policyDir=${lib.escapeShellArg policyDir}
            policyFile=${lib.escapeShellArg policyFile}
            desired=${lib.escapeShellArg (toString policyPlist)}
            temporaryPolicy=""

            fail() {
              printf >&2 'error: %s\n' "$1"
              exit 1
            }

            cleanup() {
              if [ -n "$temporaryPolicy" ] && { [ -e "$temporaryPolicy" ] || [ -L "$temporaryPolicy" ]; }; then
                /bin/rm -f "$temporaryPolicy"
              fi
            }
            trap cleanup EXIT

            if ! /usr/bin/plutil -lint "$desired" > /dev/null 2>&1; then
              fail "generated policy plist failed validation: $policyFile"
            fi

            if [ -L "$policyDir" ] || { [ -e "$policyDir" ] && [ ! -d "$policyDir" ]; }; then
              fail "refusing to manage an unsafe managed-preferences directory: $policyDir"
            fi

            if ! /bin/mkdir -p "$policyDir" \
              || ! /usr/sbin/chown root:wheel "$policyDir" \
              || ! /bin/chmod 0755 "$policyDir"; then
              fail "could not prepare $policyDir"
            fi

            if [ -L "$policyFile" ]; then
              fail "refusing to manage a symlink at the policy target: $policyFile"
            fi

            if [ -e "$policyFile" ] && [ ! -f "$policyFile" ]; then
              fail "refusing to replace non-file policy target: $policyFile"
            fi

            if [ -f "$policyFile" ] && /usr/bin/cmp -s "$desired" "$policyFile"; then
              if ! /usr/sbin/chown root:wheel "$policyFile" || ! /bin/chmod 0644 "$policyFile"; then
                fail "could not reconcile metadata for $policyFile"
              fi
              exit 0
            fi

            temporaryPolicy=$(/usr/bin/mktemp "$policyDir/.${name}.XXXXXX") || \
              fail "could not create a temporary policy plist"

            if ! /bin/cp "$desired" "$temporaryPolicy" \
              || ! /usr/sbin/chown root:wheel "$temporaryPolicy" \
              || ! /bin/chmod 0644 "$temporaryPolicy" \
              || ! /bin/mv -f "$temporaryPolicy" "$policyFile"; then
              fail "could not atomically install $policyFile"
            fi

            temporaryPolicy=""
            /usr/bin/killall cfprefsd > /dev/null 2>&1 || true
          '';
        bravePolicyReconciler = mkPolicyReconciler {
          name = "brave";
          policyFile = policyFiles.brave;
          policyPlist = policyPlists.brave;
        };
        chromePolicyReconciler = mkPolicyReconciler {
          name = "chrome";
          policyFile = policyFiles.chrome;
          policyPlist = policyPlists.chrome;
        };
        mkPolicyDaemon =
          {
            label,
            policyFile,
            command,
          }:
          {
            inherit command;
            serviceConfig = {
              Label = label;
              RunAtLoad = true;
              KeepAlive = {
                PathState = {
                  "${policyFile}" = false;
                };
              };
              WatchPaths = [
                policyDir
                policyFile
              ];
              ThrottleInterval = 10;
            };
          };
      in
      {
        # Brave reads mandatory macOS policies from the system managed
        # preferences domain, not from ordinary user defaults. Both Darwin
        # activation and the root launchd daemon call this same reconciler.
        system.activationScripts.postActivation.text = lib.mkAfter ''
          ${lib.escapeShellArg (toString bravePolicyReconciler)}
          ${lib.escapeShellArg (toString chromePolicyReconciler)}
        '';

        launchd.daemons = {
          "com.nolvyn.brave-managed-policies" = mkPolicyDaemon {
            label = "com.nolvyn.brave-managed-policies";
            policyFile = policyFiles.brave;
            command = bravePolicyReconciler;
          };
          "com.nolvyn.chrome-managed-policies" = mkPolicyDaemon {
            label = "com.nolvyn.chrome-managed-policies";
            policyFile = policyFiles.chrome;
            command = chromePolicyReconciler;
          };
        };
      };

    homeManager =
      { pkgs, ... }:
      {
        programs.brave = {
          enable = true;
          package = pkgs.unstable.brave;
        };

        programs.google-chrome = {
          enable = true;
          package = pkgs.warm.google-chrome;
        };

        # Darwin extension force-installation is handled by the root-owned
        # managed-preferences plists in the system block. This avoids writing
        # into browser-owned Application Support directories.
      };
  };
}
