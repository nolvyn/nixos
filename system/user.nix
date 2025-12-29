# user.nix
{ config, pkgs, lib, ... }:

{
  # Define a user account. 
  users.users.${config.user.name} = {
    isNormalUser = true;
    extraGroups = [
      # "dialout"
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [];
  };

  hjem.users.${config.user.name} = {
    enable = true;
    clobberFiles = lib.mkForce true;
    files = {
      ".config/waybar/config".source = ../config/waybar/config;
      ".config/waybar/style.css".source = ../config/waybar/style.css;
      ".config/fuzzel/fuzzel.ini".source = ../config/fuzzel.ini;
      ".config/walker/init.txt".text = "";
      ".config/fastfetch/config.jsonc".source = ../config/fastfetch/config.jsonc;

      ".config/kitty/kitty.conf".source = ../config/kitty.conf;

      ".config/vesktop/settings.json".source = ../config/vesktop/vesktop-settings.json;
      ".config/vesktop/settings/settings.json".source = ../config/vesktop/vencord-settings.json;
    };
  };
}
