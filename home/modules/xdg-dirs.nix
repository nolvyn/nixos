{ config, ... }:

{
  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    setSessionVariables = true;
    desktop = "${config.home.homeDirectory}/Downloads";
    documents = "${config.home.homeDirectory}/Downloads";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Downloads";
    pictures = "${config.home.homeDirectory}/Downloads";
    publicShare = "${config.home.homeDirectory}/Downloads";
    templates = "${config.home.homeDirectory}/Downloads";
    videos = "${config.home.homeDirectory}/Downloads";
  };
}
