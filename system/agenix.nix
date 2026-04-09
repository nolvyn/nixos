{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  age.secrets = {
    weeb-password.file = ../secrets/weeb-password.age;
    root-password.file = ../secrets/root-password.age;
    wifi-secrets.file = ../secrets/wifi-secrets.age;
  }
  // lib.optionalAttrs (config.networking.hostName == "WeebMachine") {
    syncthing-weebmachine-key.file = ../secrets/syncthing-weebmachine-key.age;
    syncthing-weebmachine-cert.file = ../secrets/syncthing-weebmachine-cert.age;
  }
  // lib.optionalAttrs (config.networking.hostName == "MoeNote") {
    syncthing-moenote-key.file = ../secrets/syncthing-moenote-key.age;
    syncthing-moenote-cert.file = ../secrets/syncthing-moenote-cert.age;
  };
}
