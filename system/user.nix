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
      ".config/btop/btop.conf".text = ''
        color_theme = "matugen"
        theme_background = False
      '';

      ".config/fastfetch/config.jsonc".source = ../config/fastfetch/config.jsonc;

      ".config/kitty/kitty.conf".source = ../config/kitty/kitty.conf;

      ".config/vesktop/settings.json".source = ../config/vesktop/vesktop-settings.json;
      ".config/vesktop/settings/settings.json".source = ../config/vesktop/vencord-settings.json;

      ".config/yazi/yazi.toml".source = ../config/yazi/yazi.toml;
    };
  };
}
