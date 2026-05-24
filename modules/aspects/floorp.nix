{ ... }:
{
  den.aspects.floorp = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".floorp"
      ];
    };

    homeManager = {pkgs, ...}:
      let
        lock = val: {
          Value = val;
          Status = "locked";
        };
      in
      {
        programs.floorp = {
          enable = true;

          policies = {
            DisableTelemetry = true;
            DisableFirefoxStudies = true;
            DisableFirefoxScreenshots = true;
            DisablePocket = true;
            DontCheckDefaultBrowser = true;
            DisableFormHistory = true;
            HttpsOnlyMode = "force_enabled";
            AppAutoUpdate = false;
            BackgroundAppUpdate = false;
            PasswordManagerEnabled = false;
            OfferToSaveLogins = false;
            AutofillAddressEnabled = false;
            AutofillCreditCardEnabled = false;
            NetworkPrediction = false;
            NewTabPage = false;
            DisableRemoteImprovements = true;
            SkipTermsOfUse = true;
            VisualSearchEnabled = false;
            DisableFeedbackCommands = true;
            PostQuantumKeyAgreementEnabled = true;

            GenerativeAI = {
              Default = {
                Value = "blocked";
                Locked = true;
              };
            };

            EnableTrackingProtection = {
              Value = true;
              Locked = true;
              Category = "strict";
              BaselineExceptions = true;
              ConvenienceExceptions = true;
            };

            Cookies = {
              Behavior = "reject-tracker-and-partition-foreign";
              BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
              Locked = true;
            };

            Permissions = {
              Camera = { BlockNewRequests = true; Locked = true; };
              Microphone = { BlockNewRequests = true; Locked = true; };
              Notifications = { BlockNewRequests = true; Locked = true; };
              Location = { BlockNewRequests = true; Locked = true; };
            };

            UserMessaging = {
              WhatsNew = false;
              ExtensionRecommendations = false;
              FeatureRecommendations = false;
              UrlbarInterventions = false;
              SkipOnboarding = true;
              Locked = true;
            };

            Preferences = {
              # These prefs ARE on the policy allowlist and lock successfully

              # Privacy
              # "privacy.fingerprintingProtection" = lock true;
              "privacy.userContext.enabled" = lock true;

              # Network
              # "network.http.referer.XOriginPolicy" = lock 2;
              "network.http.referer.XOriginTrimmingPolicy" = lock 2;
              "network.http.speculative-parallel-limit" = lock 0;

              # WebRTC
              "media.peerconnection.ice.default_address_only" = lock true;
              "media.peerconnection.ice.no_host" = lock true;

              # Crash reporting
              "browser.tabs.crashReporting.sendReport" = lock false;
              "browser.crashReports.unsubmittedCheck.autoSubmit2" = lock false;

              # Mozilla services
              "browser.discovery.enabled" = lock false;
              "browser.newtabpage.activity-stream.feeds.telemetry" = lock false;
              "browser.newtabpage.activity-stream.telemetry" = lock false;
              "browser.newtabpage.activity-stream.showSponsored" = lock false;
              "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock false;

              # Convenience
              "browser.startup.page" = lock 3;
              # "browser.startup.homepage" = lock "about:blank";
              "browser.tabs.warnOnClose" = lock false;
              "browser.tabs.warnOnQuit" = lock false;
              "browser.warnOnQuit" = lock false;
              "dom.battery.enabled" = lock false;
              "dom.gamepad.enabled" = lock false;

              # userChrome needs "user" status for early startup
              "toolkit.legacyUserProfileCustomizations.stylesheets" = {
                Value = true;
                Status = "user";
              };
            };
          };

          profiles.default = {
            id = 0;
            isDefault = true;

            search = {
              force = true;
              default = "kagi";
              privateDefault = "startpage";
              order = [ "kagi" "startpage" ];
              engines = {
                kagi = {
                  name = "Kagi";
                  urls = [ { template = "https://kagi.com/search?q={searchTerms}"; } ];
                  icon = "https://kagi.com/favicon.ico";
                  definedAliases = [ "@k" ];
                };
                google.metaData.hidden = true;
                bing.metaData.hidden = true;
                amazondotcom.metaData.hidden = true;
                ebay.metaData.hidden = true;
                wikipedia.metaData.hidden = true;
                ddg.metaData.hidden = true;
              };
            };

            settings = {
              # These prefs are blocked from the Preferences policy allowlist
              # so they go here and get applied via user.js on each startup

              # Sidebar / vertical tabs
              "sidebar.revamp" = true;
              "sidebar.verticalTabs" = true;
              "sidebar.visibility" = "always-show";

              # Privacy
              "privacy.donottrackheader.enabled" = true;
              # "privacy.firstparty.isolate" = true;
              "privacy.partition.network_state" = true;
              "privacy.partition.serviceWorkers" = true;

              # Telemetry
              "toolkit.telemetry.enabled" = false;
              "toolkit.telemetry.unified" = false;
              "toolkit.telemetry.archive.enabled" = false;
              "toolkit.telemetry.newProfilePing.enabled" = false;
              "toolkit.telemetry.shutdownPingSender.enabled" = false;
              "toolkit.telemetry.updatePing.enabled" = false;
              "toolkit.telemetry.bhrPing.enabled" = false;
              "toolkit.telemetry.firstShutdownPing.enabled" = false;
              "toolkit.telemetry.coverage.opt-out" = true;
              "app.normandy.enabled" = false;
              "app.normandy.api_url" = "";
              "breakpad.reportURL" = "";

              # Floorp Hub new tab
              # "floorp.newtab.url" = "about:blank";
            };
          };
        };

        systemd.user.paths.remove-floorp-dir = {
          Unit.Description = "Watch for ~/Floorp directory creation";
          Path = {
            PathExists = "%h/Floorp";
            Unit = "remove-floorp-dir.service";
          };
          Install.WantedBy = [ "default.target" ];
        };

        systemd.user.services.remove-floorp-dir = {
          Unit.Description = "Remove empty ~/Floorp directory";
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/rmdir --ignore-fail-on-non-empty %h/Floorp";
          };
        };
      };
  };
}
