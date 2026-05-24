{ ... }:
{
  den.aspects.vesktop = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".config/vesktop"
      ];
    };

    homeManager = {
      programs.vesktop = {
        enable = true;

        settings = {
          appBadge = false;
          arRPC = true;
          checkUpdates = false;
          customTitleBar = false;
          disableMinSize = true;
          discordBranch = "stable";
          hardwareAcceleration = true;
          minimizeToTray = false;
          splashBackground = "#000000";
          splashColor = "#ffffff";
          splashTheming = true;
          staticTitle = true;
        };

        vencord.settings = {
          autoUpdate = true;
          autoUpdateNotification = false;
          disableMinSize = true;
          notifyAboutUpdates = false;

          plugins = {
            AlwaysAnimate.enabled = true;
            AlwaysTrust.enabled = true;
            AnonymiseFileNames.enabled = true;
            ClearURLS.enabled = true;
            CrashHandler.enabled = true;
            CustomRPC.enabled = true;
            FakeNitro.enabled = true;
            FixImagesQuality.enabled = true;
            FixYoutubeEmbeds.enabled = true;
            MessageLogger.enabled = true;
            NoTrack.enabled = true;
            ReverseImageSearch.enabled = true;
            SilentTyping.enabled = true;
            TypingIndicator.enabled = true;
            WebScreenShareFixes.enabled = true;
            YoutubeAdblock.enabled = true;
          };

          useQuickCss = true;
        };
      };
    };
  };
}
