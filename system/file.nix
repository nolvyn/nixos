{ config, ... }:

{
  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [
        "yazi.desktop"
        "thunar.desktop"
      ];
    };
  };

  hjem.users.${config.user.name} = {
    files = {
      ".config/user-dirs.conf".text = "enabled=False";
      ".config/user-dirs.dirs".text = ''
        XDG_DESKTOP_DIR     = "/home/${config.user.name}/Downloads"
        XDG_DOCUMENTS_DIR   = "/home/${config.user.name}/Documents"
        XDG_DOWNLOAD_DIR    = "/home/${config.user.name}/Downloads"
        XDG_MUSIC_DIR       = "/home/${config.user.name}/Downloads"
        XDG_PICTURES_DIR    = "/home/${config.user.name}/Downloads"
        XDG_PUBLICSHARE_DIR = "/home/${config.user.name}/Downloads"
        XDG_TEMPLATES_DIR   = "/home/${config.user.name}/Downloads"
        XDG_VIDEOS_DIR      = "/home/${config.user.name}/Downloads"
      '';

      ".local/share/applications/yazi.desktop".source = ../applications/yazi.desktop;
      ".local/share/applications/nvim.desktop".source = ../applications/nvim.desktop;
      ".local/share/applications/neovim.desktop".source = ../applications/neovim.desktop;
    };
  };
}
