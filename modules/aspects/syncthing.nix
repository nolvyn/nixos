{ ... }:
let
  weebmachineID = "MBXVEPU-YNWBGPT-J6WSXY6-ABAXHJK-KR64XCK-M546AO5-YSKTUIV-63V2VQB";
  moenoteID = "4GHSZZG-KBMAZKQ-GXU34NY-ICZGQM2-J6EVLEK-KQVTYQL-GZYTUOF-RXTYNAA";
in
{
  den.aspects.syncthing = {
    nixos = { host, config, ... }: {
      services.syncthing = {
        enable = true;
        user = host.userName;
        group = "users";
        dataDir = "/home/${host.userName}";
        configDir = "/home/${host.userName}/.config/syncthing";
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = true;

        key =
          if host.isDesktop then
            config.age.secrets.syncthing-weebmachine-key.path
          else
            config.age.secrets.syncthing-moenote-key.path;

        cert =
          if host.isDesktop then
            config.age.secrets.syncthing-weebmachine-cert.path
          else
            config.age.secrets.syncthing-moenote-cert.path;

        settings = {
          devices = {
            WeebMachine = { id = weebmachineID; };
            MoeNote = { id = moenoteID; };
          };

          folders = {
            "Downloads" = {
              path = "/home/${host.userName}/Downloads";
              devices = [ "WeebMachine" "MoeNote" ];
              versioning = { type = "trashcan"; params.cleanoutDays = "30"; };
            };
            "host-keys" = {
              path = "/home/${host.userName}/nixos/secrets/host-keys";
              devices = [ "WeebMachine" "MoeNote" ];
              versioning = { type = "trashcan"; params.cleanoutDays = "30"; };
            };
            "other" = {
              path = "/home/${host.userName}/other";
              devices = [ "WeebMachine" "MoeNote" ];
              versioning = { type = "trashcan"; params.cleanoutDays = "30"; };
            };
            "school" = {
              path = "/home/${host.userName}/school";
              devices = [ "WeebMachine" "MoeNote" ];
              versioning = { type = "trashcan"; params.cleanoutDays = "30"; };
            };
          };
        };
      };
    };
  };
}
