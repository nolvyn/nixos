{ config, pkgs, lib, ... }:

{
  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.kde.dolphin.desktop" ];
  };

  hjem.users.${config.user.name} = {
    files = {
      ".config/user-dirs.dirs".source = ./config/user-dirs.dirs;
      ".config/user-dirs.conf".text = "enabled=False";
    };
  };
}
