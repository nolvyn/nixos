# user.nix
{
  config,
  lib,
  ...
}:

{
  users.mutableUsers = false;

  users.users.root = {
    hashedPasswordFile = config.age.secrets.root-password.path;
  };

  users.users.${config.user.name} = {
    hashedPasswordFile = config.age.secrets.weeb-password.path;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  hjem.users.${config.user.name} = {
    enable = true;
    clobberFiles = lib.mkForce true;
    files = {
      ".config/walker/.init".text = "";
      ".config/fastfetch/config.jsonc".source = ../config/fastfetch/config.jsonc;

      ".config/kitty/kitty.conf".source = ../config/kitty.conf;

      ".config/vesktop/settings.json".source = ../config/vesktop/vesktop-settings.json;
      ".config/vesktop/settings/settings.json".source = ../config/vesktop/vencord-settings.json;
    };
  };
}
