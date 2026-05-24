{ ... }:
{
  den.aspects.qbittorrent = {
    nixos = { host, pkgs, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        "torrents"
        ".config/qBittorrent"
        ".local/share/qBittorrent"
      ];

      environment.systemPackages = with pkgs; [
        qbittorrent
      ];
    };
  };
}
