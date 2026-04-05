# git.nix
{ ... }:

# Check out https://www.youtube.com/watch?v=20BN4gqHwaQ
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user.name = "nolvyn";
      user.email = "245221879+nolvyn@users.noreply.github.com";
      init.defaultBranch = "main";
      safe.directory = [ "/home/weeb/nixos" ];
    };
  };
}
