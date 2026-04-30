{ config, lib, ... }:

{
  options = {
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "weeb";
      };

      flakeDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.user.name}/nixos";
      };
    };

    machine = {
      isDesktop = lib.mkEnableOption "Desktop Machine Configuration";
      isLaptop = lib.mkEnableOption "Laptop Configuration";
    };
  };
}
