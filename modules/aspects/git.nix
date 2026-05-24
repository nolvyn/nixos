# git.nix

# Check out https://www.youtube.com/watch?v=20BN4gqHwaQ
{ ... }:
{
  den.aspects.git = {
    nixos = { host, ... }: {
      programs.git = {
        enable = true;
        lfs.enable = true;
        config = {
          user.name = host.git.userName;
          user.email = host.git.userEmail;
          init.defaultBranch = "main";
          safe.directory = [ host.flakeDir ];
        };
      };
    };
  };
}
