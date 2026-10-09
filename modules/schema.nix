{ ... }:
{
  den.schema.host = { host, lib, ... }: {
    options = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "weeb";
      };

      flakeDir = lib.mkOption {
        type = lib.types.str;
        default =
          if host.class == "darwin" then "/Users/${host.userName}/nixos" else "/home/${host.userName}/nixos";
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
  };
}
