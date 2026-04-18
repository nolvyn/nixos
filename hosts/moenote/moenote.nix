{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./moenote-hardware.nix
    ../../system/tlp.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  networking.hostName = "MoeNote";

  users.users.${config.user.name} = { };

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;

      ".config/hypr/autostart-mn.conf".source = ../../config/hypr/modules/autostart-mn.conf;
      ".config/hypr/autostart-wm.conf".text = "";
    };
  };

  services.fprintd.enable = true;

  services.upower.enable = true;
}
