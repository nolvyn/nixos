{ den, ... }:
{
  # NixOS policy that does not itself select a desktop or storage layout.
  den.aspects.nixosBase = {
    includes = with den.aspects; [
      cache
      locale
      optimizations
    ];
  };
}
