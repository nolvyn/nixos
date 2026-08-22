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

        # Brave's macOS enterprise-policy path is deliberately not synthesized
        # as user defaults or a managed-preferences activation hack here. The
        # Linux policy source remains authoritative until a robust profile/MDM
        # mechanism is available for Darwin.
      };
  };
}
