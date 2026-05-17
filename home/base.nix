{ osConfig, ... }:
{
  imports = [
    ./modules/btop.nix
    ./modules/fastfetch.nix
    ./modules/floorp.nix
    ./modules/kitty.nix
    ./modules/vesktop.nix
    ./modules/vscode.nix
    ./modules/yazi.nix
    ./modules/zed.nix
  ];

  home.username = osConfig.user.name;
  home.homeDirectory = "/home/${osConfig.user.name}";
  home.stateVersion = "25.11";
}
