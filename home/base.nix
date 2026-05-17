{ osConfig, ... }:
{
  imports = [
    ./modules/floorp.nix
  ];

  home.username = osConfig.user.name;
  home.homeDirectory = "/home/${osConfig.user.name}";
  home.stateVersion = "25.11";
}
