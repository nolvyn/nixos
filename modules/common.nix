{ den, ... }:
{
  # Keep this aspect portable. Role-specific system integration and personal
  # workstation applications belong in modules/profiles.nix.
  den.aspects.common = {
    includes = with den.aspects; [
      btop
      fastfetch
      ghostty
      git
      kitty
      yazi
    ];
  };
}
