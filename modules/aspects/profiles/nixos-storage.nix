{ den, ... }:
{
  # Current WeebMachine storage policy. Disko and the rollback service assume
  # its NVMe/LUKS/Btrfs layout; this is not a generic NixOS server profile.
  den.aspects.nixosStorage = {
    includes = with den.aspects; [
      btrfs
      disko
      impermanence
    ];
  };
}
