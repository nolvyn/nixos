{ config, osConfig, ... }:
{
  imports = [
    ./modules/btop.nix
    ./modules/fastfetch.nix
    ./modules/floorp.nix
    ./modules/hyprland.nix
    ./modules/kitty.nix
    ./modules/vesktop.nix
    ./modules/vscode.nix
    ./modules/xdg-dirs.nix
    ./modules/yazi.nix
    ./modules/zed.nix
  ];

  home.username = osConfig.user.name;
  home.homeDirectory = "/home/${osConfig.user.name}";
  home.stateVersion = "25.11";

  home.file = {
    ".local/share/applications/yazi.desktop".source = ../applications/yazi.desktop;
    ".local/share/applications/nvim.desktop".source = ../applications/nvim.desktop;
    ".local/share/applications/neovim.desktop".source = ../applications/neovim.desktop;

    ".config/gtk-3.0/gtk.css".text = "@import 'colors.css';";
    ".config/gtk-4.0/gtk.css".text = "@import 'colors.css';";

    ".config/matugen/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/config/matugen/config.toml";
  };
}
