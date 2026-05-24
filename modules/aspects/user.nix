{ den, ... }:
{
  den.aspects.user = {
    nixos = { host, config, ... }: {
      users.mutableUsers = false;
      users.users.root.hashedPasswordFile = config.age.secrets.root-password.path;
      users.users.${host.userName}.hashedPasswordFile = config.age.secrets.weeb-password.path;
    };

    homeManager = { host, config, ... }: {
      home.file = {
        ".local/share/applications/yazi.desktop".source = ../../applications/yazi.desktop;
        ".local/share/applications/nvim.desktop".source = ../../applications/nvim.desktop;
        ".local/share/applications/neovim.desktop".source = ../../applications/neovim.desktop;

        ".config/gtk-3.0/gtk.css".text = "@import 'colors.css';";
        ".config/gtk-4.0/gtk.css".text = "@import 'colors.css';";

        ".config/matugen/config.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${host.flakeDir}/config/matugen/config.toml";
      };
    };
  };

  den.aspects.weeb = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
      den.batteries.host-aspects
    ];
  };
}
