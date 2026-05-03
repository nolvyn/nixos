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
    };
  };

  services.fprintd.enable = true;

  services.upower.enable = true;
}
