{
  config,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../system/tlp.nix
  ];

  machine.isLaptop = true;

  networking.hostName = "MoeNote";

  hjem.users.${config.user.name} = {
    files = {
      ".config/hypr/hypridle.conf".source = ../../config/hypr/hypridle.conf;
      ".config/hypr/autostart-extra.conf".source = ../../config/hypr/modules/autostart-mn.conf;
    };
  };

  services.fprintd.enable = true;

  services.upower.enable = true;
}
