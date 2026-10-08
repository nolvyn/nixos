{ inputs, ... }:
{
  flake-file.inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.agenix = {
    nixos =
      {
        pkgs,
        ...
      }:
      {
        imports = [ inputs.agenix.nixosModules.default ];
        environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

        age.identityPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];

        age.secrets = {
          weeb-password.file = ../../secrets/weeb-password.age;
          root-password.file = ../../secrets/root-password.age;
        };
      };
  };
}
