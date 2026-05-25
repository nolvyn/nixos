{ den, ... }:
{
  den.aspects.user = {
    nixos = { host, config, ... }: {
      users.mutableUsers = false;
      users.users.root.hashedPasswordFile = config.age.secrets.root-password.path;
      users.users.${host.userName}.hashedPasswordFile = config.age.secrets.weeb-password.path;
    };

  };

  den.aspects.weeb = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
      den.batteries.host-aspects
    ];
  };
}
