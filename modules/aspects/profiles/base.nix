{ den, ... }:
{
  # Keep this aspect portable; put role-specific system integration and personal workstation apps in sibling profiles.
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
