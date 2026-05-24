{ ... }:
{
  den.aspects.virtualization = {
    nixos =
      { host, ... }:
      {
        # For more information see https://nixos.wiki/wiki/Virt-manager
        virtualisation.libvirtd.enable = true;
        programs.virt-manager.enable = true;

        users.users.${host.userName}.extraGroups = [ "libvirtd" ];

        # For more information see https://wiki.nixos.org/wiki/Waydroid
        # virtualisation.waydroid.enable = true;
      };
  };
}
