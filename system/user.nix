# user.nix
{
  config,
  ...
}:

{
  users.mutableUsers = false;

  users.users.root = {
    hashedPasswordFile = config.age.secrets.root-password.path;
  };

  users.users.${config.user.name} = {
    hashedPasswordFile = config.age.secrets.weeb-password.path;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
