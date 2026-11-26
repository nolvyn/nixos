{ den, ... }:
{
  # WeebMachine-specific storage policy. Disko and rollback assume its NVMe/LUKS/Btrfs layout.
  den.aspects.nixosStorage = {
    includes = with den.aspects; [
      btrfs
      disko
      impermanence
    ];
  };
}
