{ pkgs, inputs, ... }:

{
  environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  age.secrets = {
    weeb-password.file = ../secrets/weeb-password.age;
    root-password.file = ../secrets/root-password.age;
  };
}
