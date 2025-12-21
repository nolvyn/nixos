# browser.nix
{ config, pkgs, lib, ... }:

{
  programs.chromium = {
    enable = true;

    extensions = [
      # "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
      "gbefmodhlophhakmoecijeppjblibmie" # Linguist
      "ponfpcnoihfmfllpaingbgckeeldkhle" # Enhancer for YouTube
      "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
    ];

    extraOpts = {
      # Brave-Specific Policies
      "BraveAIChatEnabled" = false;
      "BraveNewsDisabled" = true;
      "BraveP3AEnabled" = false;
      "BravePlaylistEnabled" = false;
      "BraveRewardsDisabled" = true;
      "BraveSpeedreaderEnabled" = false;
      "BraveStatsPingEnabled" = false;
      "BraveTalkDisabled" = true;
      "BraveVPNDisabled" = true;
      "BraveWalletDisabled" = true;
      "BraveWaybackMachineEnabled" = true;
      "BraveWebDiscoveryEnabled" = false;
      "TorDisabled" = true;

      # Default Permission Settings (2 = Block)
      "DefaultGeolocationSetting" = 2;
      "DefaultLocalFontsSetting" = 2;
      "DefaultNotificationsSetting" = 2;
      "DefaultSensorsSetting" = 2;
      "DefaultSerialGuardSetting" = 2;

      # Reporting & Telemetry
      "CloudReportingEnabled" = false;
      "MetricsReportingEnabled" = false;
      "UrlKeyedAnonymizedDataCollectionEnabled" = false;

      # Safe Browsing Features
      "AlternateErrorPagesEnabled" = false;
      "SafeBrowsingDeepScanningEnabled" = false;
      "SafeBrowsingExtendedReportingEnabled" = false;
      "SafeBrowsingProtectionLevel" = 1; # Standard Protection
      "SafeBrowsingSurveysEnabled" = false;

      # Autofill & Passwords
      "AutofillAddressEnabled" = false;
      "AutofillCreditCardEnabled" = false;
      "PasswordLeakDetectionEnabled" = false;
      "PasswordManagerEnabled" = false;
      "PasswordSharingEnabled" = false;

      # Privacy & Security
      "BlockThirdPartyCookies" = true;
      "EnableMediaRouter" = false;
      "ForceGoogleSafeSearch" = false;
      "HttpsOnlyMode" = "force_enabled";
      "RelatedWebsiteSetsEnabled" = false;
      "ShoppingListEnabled" = false;
      "PrivacySandboxAdTopicsEnabled" = false;
      "PrivacySandboxSiteEnabledAdsEnabled" = false;
      "PrivacySandboxAdMeasurementEnabled" = false;
      "WebRtcIPHandling" = "disable_non_proxied_udp";

      # Browser Behavior
      "DefaultBrowserSettingEnabled" = false;
      "DesktopSharingHubEnabled" = false;
      "PromptForDownloadLocation" = false;
      "PromotionsEnabled" = false;
      "ShowCastIconInToolbar" = false;
      "SpellCheckServiceEnabled" = false;
      "ClearBrowsingDataOnExitList" = [
        "download_history"
        "password_signin"
        "autofill"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    brave
  ];
}
