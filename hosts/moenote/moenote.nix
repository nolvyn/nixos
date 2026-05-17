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

  services.fprintd.enable = true;

  services.upower.enable = true;

  home-manager.users.${config.user.name} = import ../../home/hosts/moenote.nix;
}
