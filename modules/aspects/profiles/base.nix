{ den, ... }:
{
  # Keep this aspect portable. Role-specific system integration and personal
  # workstation applications belong in the other profile files in this directory.
  den.aspects.base = {
    includes = with den.aspects; [
      fastfetch
      ghostty
      git
      kitty
      yazi
    ];
  };
}
