{ config, ... }:

let
  isWeebMachine = config.networking.hostName == "WeebMachine";

  weebmachineID = "MBXVEPU-YNWBGPT-J6WSXY6-ABAXHJK-KR64XCK-M546AO5-YSKTUIV-63V2VQB";
  moenoteID = "4GHSZZG-KBMAZKQ-GXU34NY-ICZGQM2-J6EVLEK-KQVTYQL-GZYTUOF-RXTYNAA";
in

{
  services.syncthing = {
    enable = true;
    user = config.user.name;
    group = "users";
    dataDir = "/home/${config.user.name}";
    configDir = "/home/${config.user.name}/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;

    key =
      if isWeebMachine then
        config.age.secrets.syncthing-weebmachine-key.path
      else
        config.age.secrets.syncthing-moenote-key.path;

    cert =
      if isWeebMachine then
        config.age.secrets.syncthing-weebmachine-cert.path
      else
        config.age.secrets.syncthing-moenote-cert.path;

    settings = {
      devices = {
        WeebMachine = {
          id = weebmachineID;
        };
        MoeNote = {
          id = moenoteID;
        };
      };

      folders = {
        "host-keys" = {
          path = "/home/${config.user.name}/nixos/secrets/host-keys";
          devices = [
            "WeebMachine"
            "MoeNote"
          ];
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
        "Documents" = {
          path = "/home/${config.user.name}/Documents";
          devices = [
            "WeebMachine"
            "MoeNote"
          ];
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
      };
    };
  };
}
