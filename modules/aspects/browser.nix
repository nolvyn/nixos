{ lib, ... }:
let
  browserExtensions = [
    "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
    "gbefmodhlophhakmoecijeppjblibmie" # Linguist
    "ponfpcnoihfmfllpaingbgckeeldkhle" # Enhancer for YouTube
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
  ];

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
        policyFile = "${policyDir}/com.brave.Browser.plist";
        policyPlist = (pkgs.formats.plist { }).generate "com.brave.Browser.plist" bravePolicies;
        policyPlistArg = lib.escapeShellArg (toString policyPlist);
        policyReconciler = pkgs.writeShellScript "brave-managed-policy-reconciler" ''
          set -eu

          policyDir=${lib.escapeShellArg policyDir}
          policyFile=${lib.escapeShellArg policyFile}
          desired=${policyPlistArg}
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
            fail "generated Brave policy plist failed validation"
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
            fail "refusing to manage a symlink at the Brave policy target: $policyFile"
          fi

          if [ -e "$policyFile" ] && [ ! -f "$policyFile" ]; then
            fail "refusing to replace non-file Brave policy target: $policyFile"
          fi

          if [ -f "$policyFile" ] && /usr/bin/cmp -s "$desired" "$policyFile"; then
            if ! /usr/sbin/chown root:wheel "$policyFile" || ! /bin/chmod 0644 "$policyFile"; then
              fail "could not reconcile metadata for $policyFile"
            fi
            exit 0
          fi

          temporaryPolicy=$(/usr/bin/mktemp "$policyDir/.com.brave.Browser.plist.XXXXXX") || \
            fail "could not create a temporary Brave policy plist"

          if ! /bin/cp "$desired" "$temporaryPolicy" \
            || ! /usr/sbin/chown root:wheel "$temporaryPolicy" \
            || ! /bin/chmod 0644 "$temporaryPolicy" \
            || ! /bin/mv -f "$temporaryPolicy" "$policyFile"; then
            fail "could not atomically install $policyFile"
          fi

          temporaryPolicy=""
          /usr/bin/killall cfprefsd > /dev/null 2>&1 || true
        '';
      in
      {
        # Brave reads mandatory macOS policies from the system managed
        # preferences domain, not from ordinary user defaults. Both Darwin
        # activation and the root launchd daemon call this same reconciler.
        system.activationScripts.postActivation.text = lib.mkAfter ''
          ${lib.escapeShellArg (toString policyReconciler)}
        '';

        launchd.daemons."com.nolvyn.brave-managed-policies" = {
          command = policyReconciler;
          serviceConfig = {
            Label = "com.nolvyn.brave-managed-policies";
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
      };

    homeManager =
      { host, pkgs, ... }:
      {
        programs.brave = {
          enable = true;
          package = pkgs.warm.brave;
          # Linux Chromium policy owns the force-installed extensions for both
          # Brave and Google Chrome. Home Manager owns them on Darwin.
          extensions = lib.optionals (lib.hasSuffix "darwin" host.system) browserExtensions;
        };

        programs.google-chrome = {
          enable = true;
          package = pkgs.warm.google-chrome;
          # Home Manager's Linux module intentionally rejects external
          # extensions for proprietary Chrome. Darwin supports the Web Store
          # update mechanism, so keep the shared extensions there.
          extensions = lib.optionals (lib.hasSuffix "darwin" host.system) browserExtensions;
        };

        # The shared bravePolicies attrset is installed by the Darwin system
        # block as a root-owned managed-preferences plist. A configuration
        # profile fallback remains deliberately out of scope.
      };
  };
}
