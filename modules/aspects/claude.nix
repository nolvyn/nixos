{ ... }:
{
  den.aspects.claude = {
    nixos =
      { host, pkgs, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".claude" ];
          files = [ ".claude.json" ];
        };

        environment.systemPackages = with pkgs; [
          unstable.claude-code
        ];
      };
  };
}
