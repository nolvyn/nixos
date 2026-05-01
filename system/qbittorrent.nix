{pkgs, ...}:

{
  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent;
  };
}
