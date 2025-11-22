# firefox.nix
{ config, pkgs, lib, ... }:

let
  lock = val: { Value = val; Status = "locked"; };
in 
{
  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisableFirefoxScreenshots = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;

      PasswordManagerEnabled = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      DisableFormHistory = true;

      HttpsOnlyMode = "force_enabled";

      DisplayBookmarksToolbar = "always";

      UserMessaging = {
        WhatsNew = false;
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
      };

      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        Stories = false;
        SponsoredPocket = false;
        SponsoredStories = false;
        Snippets = false;

        Locked = true;
      };

      Preferences = {
        "browser.startup.page" = lock 3;
        "browser.startup.restoreTabs" = lock true;
        "browser.sessionstore.resume_from_crash" = lock true;

        "privacy.resistFingerprinting" = lock true;
        "privacy.firstparty.isolate" = lock true;
        "privacy.partition.network_state" = lock true;

        "privacy.donottrackheader.enabled" = lock true;
        "privacy.donottrackheader.value" = lock 1;

        "network.http.referer.XOriginPolicy" = lock 2;
        "network.http.referer.XOriginTrimmingPolicy" = lock 2;

        "dom.battery.enabled" = lock false;
        "dom.gamepad.enabled" = lock false;

        "media.peerconnection.enabled" = lock false;
      };

      Permissions = {
        Camera = {
          BlockNewRequests = true;
          Locked = true;
        };
        Microphone = {
          BlockNewRequests = true;
          Locked = true;
        };
        Notifications = {
          BlockNewRequests = true;
          Locked = true;
        };
        Location = {
          BlockNewRequests = true;
          Locked = true;
        };
      };
    };
  };
}
