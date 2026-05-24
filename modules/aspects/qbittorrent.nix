{ ... }:
{
  den.aspects.qbittorrent = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        qbittorrent
      ];
    };
  };
}
