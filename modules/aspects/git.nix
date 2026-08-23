{ ... }:
{
  den.aspects.git = {
    homeManager = { host, pkgs, ... }: {
      home.packages = with pkgs; [
        gh
      ];
      programs.git = {
        enable = true;
        lfs.enable = true;
        settings = {
          user.name = host.git.userName;
          user.email = host.git.userEmail;
          init.defaultBranch = "main";
          safe.directory = [ host.flakeDir ];
          credential."https://github.com".helper = [
            ""
            "${pkgs.gh}/bin/gh auth git-credential"
          ];
        };
      };
    };
  };
}
