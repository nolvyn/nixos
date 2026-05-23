# NixOS → Den v0.17.0 Migration

## READ FIRST -- Do This Before Writing Any Code
Read these files in full before doing anything else:
  .docs/den/den-docs.txt
  .docs/den/den-modules.txt
  .docs/den/den-nix-source.txt
  .docs/den/den-templates.txt

Then read every .nix file in system/, home/, and hosts/ to understand
what exists before rewriting it. Do not write a single file until you
have done both of these things and confirmed it.

## Safety
- NEVER run nixos-rebuild switch or nixos-rebuild boot
- Only run: nix flake check OR nix eval .#nixosConfigurations.WeebMachine
- Never touch: config/ secrets/ assets/ applications/ scripts/
- Never delete an existing file without asking first
- git add -A && git commit before making large changes

## What Is Happening
system/ and home/ are being deleted. Their content moves into modules/aspects/.
Every feature gets one .nix file that contains both its NixOS config (nixos block)
and its home-manager config (homeManager block) together in one place.
configuration.nix is deleted. hosts/ is deleted. flake.nix is rewritten.

## Target Structure
modules/
├── setup.nix
├── schema.nix
└── aspects/
    ├── hosts/
    │   ├── weebmachine/
    │   │   ├── weebmachine.nix
    │   │   └── hardware.nix
    │   └── moenote/
    │       ├── moenote.nix
    │       └── hardware.nix
    ├── security/
    │   ├── general.nix
    │   ├── kernel.nix
    │   ├── network.nix
    │   ├── ssh.nix
    │   └── systemd.nix
    ├── agenix.nix
    ├── audio.nix
    ├── bluetooth.nix
    ├── browser.nix
    ├── btrfs.nix
    ├── btop.nix
    ├── cache.nix
    ├── dev.nix
    ├── disko-btrfs.nix
    ├── fastfetch.nix
    ├── file.nix
    ├── fish.nix
    ├── floorp.nix
    ├── fonts.nix
    ├── gaming.nix
    ├── git.nix
    ├── hyprland.nix
    ├── impermanence.nix
    ├── keyboard.nix
    ├── kitty.nix
    ├── locale.nix
    ├── location.nix
    ├── optimizations.nix
    ├── printing.nix
    ├── qbittorrent.nix
    ├── sddm.nix
    ├── syncthing.nix
    ├── theme.nix
    ├── tlp.nix
    ├── user.nix
    ├── vesktop.nix
    ├── virtualization.nix
    ├── vscode.nix
    ├── xdg-dirs.nix
    ├── yazi.nix
    └── zed.nix

## Den API -- Non-Negotiable Rules
- den.ctx is DEPRECATED. Never use it under any circumstances.
- Use den.aspects, den.schema, den.default, den.policies instead.
- Home-manager wiring is AUTOMATIC. Den handles it when users have
  classes=["homeManager"] and inputs.home-manager exists in flake.nix.
- Do NOT set home-manager.useGlobalPkgs or useUserPackages manually.
- Do NOT manually import inputs.home-manager.nixosModules.home-manager.
- inputs is a module argument everywhere. No specialArgs needed.
- Flat-form class modules MUST include ... in their args or eval will error:
    nixos = { host, config, pkgs, ... }: { ... }   <- correct
    nixos = { host, config, pkgs }: { ... }         <- WRONG, will crash

## Batteries -- All Are Opt-In, Must Be Explicitly Included
- den.batteries.define-user: sets users.users.weeb, home.username, home.homeDirectory
  Include it in setup.nix: den.default.includes = [ den.batteries.define-user ... ]
- den.batteries.hostname: sets networking.hostName from host.hostName
  Include it in setup.nix: den.default.includes = [ ... den.batteries.hostname ]
- den.batteries.primary-user: adds wheel + networkmanager groups, sets isNormalUser
  Include it in aspects/user.nix: den.aspects.weeb.includes = [ den.batteries.primary-user ... ]
- den.batteries.user-shell: sets fish shell at OS and HM level
  Include it in aspects/user.nix: den.aspects.weeb.includes = [ ... (den.batteries.user-shell "fish") ]
- Do NOT declare users.users.weeb, home.username, home.homeDirectory, or
  users.users.weeb.shell manually. The batteries handle all of this.

## setup.nix Requirements
- imports = [ inputs.den.flakeModule ]
- den.schema.user.classes = lib.mkDefault [ "homeManager" ]
- den.default.includes = [ den.batteries.define-user den.batteries.hostname ]
- den.default.nixos must contain:
    nixpkgs.config.allowUnfree = true
    nixpkgs.overlays (stable overlay, moe-gaming overlay, nix-vscode-extensions overlay)
    imports for: aagl, agenix, disko, impermanence, stevenblack-hosts nixos modules
    nix.settings.experimental-features = [ "nix-command" "flakes" ]
    system.stateVersion = "25.11"
- den.default.homeManager.home.stateVersion = "25.11"

## schema.nix Requirements
All options live here under den.schema.host = { host, lib, ... }: { options = { ... }; }:
- userName: str, default "weeb"
- flakeDir: str, default "/home/${host.userName}/nixos"
- git.userName: str, default "nolvyn"
- git.userEmail: str, default "245221879+nolvyn@users.noreply.github.com"
- isDesktop: mkEnableOption
- isLaptop: mkEnableOption

## Hosts
WeebMachine: x86_64-linux, isDesktop = true, user weeb (homeManager class)
  Includes all aspects except tlp
  Weebmachine-only: gaming, printing, qbittorrent

MoeNote: x86_64-linux, isLaptop = true, user weeb (homeManager class)
  Includes all aspects except gaming, printing, qbittorrent
  MoeNote-only: tlp

## Conditional Aspects
- gaming.nix: wrap entire nixos body in lib.optionalAttrs host.isDesktop { ... }
- impermanence.nix: desktop-only persist dirs use lib.optionals host.isDesktop [ ... ]
- tlp.nix: only included by moenote.nix
- printing.nix: only included by weebmachine.nix
- qbittorrent.nix: only included by weebmachine.nix
- hypridle.conf symlink: only in MoeNote's homeManager block (laptops need it)

## File Merger Map
system/hyprland.nix + home/modules/hyprland.nix → aspects/hyprland.nix
system/browser.nix → aspects/browser.nix nixos block
home/modules/floorp.nix → aspects/floorp.nix homeManager block
system/dev.nix → aspects/dev.nix nixos block
home/modules/vscode.nix → aspects/vscode.nix homeManager block
system/user.nix → aspects/user.nix nixos block
home/base.nix + home/modules/xdg-dirs.nix → aspects/user.nix homeManager block
  (desktop file symlinks and matugen config link also go in user.nix homeManager block)
system/security/general.nix → aspects/security/general.nix
system/security/kernel.nix → aspects/security/kernel.nix
system/security/network.nix → aspects/security/network.nix
system/security/ssh.nix → aspects/security/ssh.nix
system/security/systemd.nix → aspects/security/systemd.nix
system/options.nix → modules/schema.nix + parts absorbed into setup.nix
configuration.nix → content distributed into setup.nix and individual aspects
home/modules/btop.nix → aspects/btop.nix homeManager block
home/modules/fastfetch.nix → aspects/fastfetch.nix homeManager block
home/modules/kitty.nix → aspects/kitty.nix homeManager block
home/modules/vesktop.nix → aspects/vesktop.nix homeManager block
home/modules/yazi.nix → aspects/yazi.nix homeManager block
home/modules/zed.nix → aspects/zed.nix homeManager block
home/modules/xdg-dirs.nix → aspects/xdg-dirs.nix homeManager block
