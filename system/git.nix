# git.nix
{ config, pkgs, lib, ... }:

# Check out https://www.youtube.com/watch?v=20BN4gqHwaQ

{
  programs.git = {
    enable = true;
    config = {
      user.name =  "nolvyn";
      user.email = "245221879+nolvyn@users.noreply.github.com";
      init.defaultBranch = "main";
      safe.directory = ["/home/weeb/nixos"];
    };
  };

  # Git Stuff
  # git add *
  # git commit -m "Update"
  # git push origin main
}
