{ config, pkgs, lib, ... }:

{
  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.kde.dolphin.desktop" ];
  };

  hjem.users.${config.user.name} = {
    files = {
      ".config/user-dirs.dirs".source = ../config/user-dirs.dirs;
      ".config/user-dirs.conf".text = "enabled=False";

      ".local/share/applications/yazi.desktop".source = ../applications/yazi.desktop;
      ".local/share/applications/nvim.desktop".source = ../applications/nvim.desktop;
      ".local/share/applications/neovim.desktop".source = ../applications/neovim.desktop;
    };
  };
}
