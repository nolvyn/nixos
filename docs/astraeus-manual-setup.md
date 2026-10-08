# Astraeus manual setup

These are the manual steps for restoring the declared Astraeus environment on
an Apple Silicon Mac. Packages, app links, launchd jobs, browser extension
policies, Fish, and the OmniWM configuration are managed by this repository.
Personal data, account sessions, and Apple security approvals remain outside Nix.
All shared applications and tools come from `common`; Astraeus adds the
Determinate, Homebrew, OmniWM, and mac-app-util foundations and host overrides.

## Bootstrap

1. Create or use the macOS administrator account `nolan`, with home
   `/Users/nolan`. The current host declaration expects this existing account.
2. Install [Determinate Nix using its macOS package installer](https://determinate.systems/install/),
   then open a new terminal. Determinate owns the Nix installation;
   `determinateNix.enable = true` keeps nix-darwin's `nix.enable = false`.
3. Clone the repository to `/Users/nolan/nixos`. If Git is unavailable, use a
   temporary Nix shell rather than invoking Apple's Git shim and installing CLT:

   ```sh
   nix shell 'https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1#git'
   git clone https://github.com/nolvyn/nixos.git /Users/nolan/nixos
   cd /Users/nolan/nixos
   ```

4. Build the locked configuration as your user, then activate using the rebuild
   command in that result. This also bootstraps nix-darwin and Home Manager:

   ```sh
   nix build .#darwinConfigurations.Astraeus.system
   sudo ./result/sw/bin/darwin-rebuild switch --flake .#Astraeus
   ```

   Subsequent changes use `darwin-rebuild build --flake .#Astraeus` and
   `sudo darwin-rebuild switch --flake .#Astraeus`. Inspect any activation
   collision before moving an existing file; do not blindly overwrite it.
5. Log out and back in if separate Spaces changed, and to start a new session
   with Fish and the managed environment. Keep the checkout at the declared
   path: OmniWM reads `config/omniwm/settings.toml` through a live symlink.
   Keep intended settings edits in the repository and commit them.

Homebrew is bootstrapped at `/opt/homebrew` by nix-homebrew. Do not run a separate
Homebrew installer. The declared casks are Proton VPN (`protonvpn`, owned by the
shared `proton` aspect) and the official ChatGPT desktop app (`chatgpt`, owned by
the shared `ai.chatgpt` aspect). Activation uninstalls undeclared formulae/casks.
Taps and cask versions remain mutable, so this reproduces package ownership
rather than identical application binaries.

The Homebrew aspect manages the installation infrastructure; individual feature
aspects own their casks. Proton Pass desktop is not declared yet; the browser
extension remains managed by the browser aspect.

ChatGPT installs as `/Applications/ChatGPT.app` through Homebrew and retains its
native updater. Do not install an additional copy through Nixpkgs, the Mac App
Store, or the deprecated `codex-app` cask. The Codex CLI remains independently
Nix-managed through `llm-agents.nix`, with its existing settings, plugins, MCP
servers, skills, and oh-my-codex integration. On Linux, the same `ai.chatgpt`
aspect retains the `codex-desktop-linux` integration and persistence.

Mac App Store apps are owned separately by nix-darwin `programs.mas`. Its desired
set is currently empty, and activation removes undeclared MAS apps (not built-in
macOS apps). Before the first switch on an existing Mac, run
`nix shell .#darwinConfigurations.Astraeus.config.programs.mas.package -c mas list`
and declare any apps you want to retain in `programs.mas.packages`. If apps are
added later, sign into the Mac App Store as `nolan` before installing them.
Activation does not run `mas update` or change Apple's Automatic Updates setting.

## Required Apple approvals

- OmniWM requires **Accessibility** and **Input Monitoring**. Approve the actual
  OmniWM application when prompted in System Settings → Privacy & Security.
  Return to its permission window, check again if necessary, and choose
  **Continue Without Screen Recording**. Its app is available through
  `~/Applications/Home Manager Apps/OmniWM.app`; Home Manager owns startup, so
  do not enable a second application-managed login item. See the
  [OmniWM launch requirements](https://github.com/OmniNull/OmniWM#requirements).
- Separate Spaces and disabling Apple's three-finger horizontal workspace
  gesture are already declared. A logout may be needed for separate Spaces.
- When first connecting Proton VPN, accept its request to add VPN configuration.
  If using WireGuard/Stealth/Smart Protocol, enable the requested Proton VPN
  network extension in System Settings → General → Login Items & Extensions →
  Network Extensions. Split tunneling has its own feature-dependent approval;
  it is not required just to reproduce the installed app. Follow
  [Proton's network extension instructions](https://protonvpn.com/support/macos-network-extensions)
  for the prompts presented by your selected features.

## Accounts and personal state

- Run `gh auth login` when GitHub authentication is needed; the declared Git
  credential helper uses GitHub CLI. Retain credentials in its supported local
  storage/Keychain, never in this repository.
- Launch `/Applications/ChatGPT.app` and sign in to OpenAI after activation.
  Desktop sign-in and feature-dependent macOS permissions remain manual.
- Sign in to Proton VPN and Proton Pass, Filen, Slack, Spotify, Vesktop,
  browsers, editors, and AI tools as needed. Restore personal browser data and
  other user files from your own backup or the relevant app's sync service.
- Browser extensions install through managed policy; no profile-directory
  migration or manual extension JSON files are required. Check `brave://policy`
  or `chrome://policy` after launching/restarting the browser if needed.

## Optional permissions and features

OmniWM Screen Recording enables capture-derived visuals such as Overview
thumbnails and drag previews. It is optional for the current window management
setup. LocalSend discovery may prompt for Local Network access; approve it only
if using transfers. Microphone, camera, notifications, and screen sharing are
choices for the apps/features you use, not bootstrap prerequisites.

## Not required

Keep SIP enabled. No MDM, TCC database edits, Full Disk Access workaround,
Terminal access to Brave/Chrome App Data, Apple CLT/Xcode, Rosetta, or Intel
Homebrew is required for this configuration. Terminal's temporary browser App
Data access used during migration is not part of fresh setup. Existing grants
can be reviewed in System Settings → Privacy & Security → Files & Folders;
their current state is not reliably established by a permission-free CLI audit.
Do not re-sign the supplied Brave or OmniWM app, enable Home Manager `copyApps`,
or install another copy of OmniWM with Homebrew.
