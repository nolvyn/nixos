{ ... }:
{
  den.aspects.neovim = {
    nixos = { host, pkgs, ... }: {
      environment.systemPackages = [ pkgs.neovim ];

      environment.persistence."/persistent".users.${host.userName} = {
        directories = [
          ".local/share/nvim"
          ".local/state/nvim"
        ];
      };
    };

    homeManager = { ... }: {
      xdg.desktopEntries = {
        neovim = {
          name = "Neovim";
          comment = "Edit text files";
          exec = "kitty -e nvim %F";
          icon = "nvim";
          categories = [
            "Utility"
            "TextEditor"
          ];
        };

        nvim = {
          name = "Neovim wrapper";
          genericName = "Text Editor";
          comment = "Edit text files";
          exec = "nvim %F";
          icon = "nvim";
          terminal = true;
          noDisplay = true;
          startupNotify = false;
          categories = [
            "Utility"
            "TextEditor"
          ];
          mimeType = [
            "text/english"
            "text/plain"
            "text/x-makefile"
            "text/x-c++hdr"
            "text/x-c++src"
            "text/x-chdr"
            "text/x-csrc"
            "text/x-java"
            "text/x-moc"
            "text/x-pascal"
            "text/x-tcl"
            "text/x-tex"
            "application/x-shellscript"
            "text/x-c"
            "text/x-c++"
          ];
        };
      };
    };
  };
}
