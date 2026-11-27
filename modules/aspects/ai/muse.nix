{ inputs, ... }:
{
  den.aspects.ai.provides.muse = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName}.directories = [
          ".config/muse"
          ".local/share/muse"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.muse-code
        ];
      };
  };
}
