{
  config,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../system/tlp.nix
  ];

  networking.hostName = "MoeNote";

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
