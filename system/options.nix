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

      git = {
        userName = lib.mkOption {
          type = lib.types.str;
          default = "nolvyn";
        };
        userEmail = lib.mkOption {
          type = lib.types.str;
          default = "245221879+nolvyn@users.noreply.github.com";
        };
      };
    };

    machine = {
      isDesktop = lib.mkEnableOption "Desktop Machine Configuration";
      isLaptop = lib.mkEnableOption "Laptop Configuration";
    };
  };
}
