# git.nix
{ config, ... }:

# Check out https://www.youtube.com/watch?v=20BN4gqHwaQ
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user.name = config.user.git.userName;
      user.email = config.user.git.userEmail;
      init.defaultBranch = "main";
      safe.directory = [ config.user.flakeDir ];
    };
  };
}
