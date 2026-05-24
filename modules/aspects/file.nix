{ ... }:
{
  den.aspects.file = {
    nixos = {
      xdg.mime = {
        enable = true;
        defaultApplications = {
          "inode/directory" = [
            "yazi.desktop"
            "nautilus.desktop"
          ];
        };
      };
    };
  };
}
