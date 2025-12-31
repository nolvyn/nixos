# flatpak.nix
{ config, pkgs, lib, ... }:

let
  gameLibraryPath = "home/Games";
  vnLibraryPath = "home/vns";

  projectPaths = [];

  animeLauncherOverrides = {
    Context = {
      shared = [ "network" "ipc" ];
      sockets = [ "x11" "wayland" "pulseaudio" ];
      devices = [ "all" ];
      filesystems = [
        "!/media"
        "!/mnt"
        "!/run/media"
      ];
    };
  };
in

{
  services.flatpak = {
    enable = true;
    uninstallUnmanaged = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      {
        appId = "com.visualstudio.code";
        origin = "flathub";
      }
    ];

    overrides = {
      /* "com.vscodium.codium" = {
        Context = {
          sockets = [ "x11" "wayland" ];
          devices = [ "!devices=all" ];
          filesystems = [
            "!host"
            "home/.micromaba-root"
            "home/.conda"
          ] ++ projectPaths;
        };
      }; */

      "net.lutris.Lutris" = {
        Context = {
          shared = [ "network" "ipc" ];
          sockets = [ "x11" "wayland" "pulseaudio" ];
          devices = [ "all" ];
          filesystems = [
            "!home"
            "!/media"
            "!/run/media"
            gameLibraryPath
            vnLibraryPath
          ];
        };
      };

      "moe.launcher.an-anime-game-launcher" = animeLauncherOverrides;
      "moe.launcher.the-honkers-railway-launcher" = animeLauncherOverrides;
      "moe.launcher.honkers-launcher" = animeLauncherOverrides;
      "moe.launcher.sleepy-launcher" = animeLauncherOverrides;
    };
  };
}
