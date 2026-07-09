{ ... }:
{
  den.aspects.cache = {
    nixos = {
      nix.settings = {
        extra-substituters = [
          "https://hyprland.cachix.org"
          "https://nix-community.cachix.org"
          "https://codex-desktop-linux.cachix.org"
        ];
        extra-trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
        ];
      };
    };
  };
}
