# Astraeus manual setup

Use an Apple Silicon Mac and the macOS administrator account `nolan` with home
`/Users/nolan`. Keep SIP enabled and use a native terminal.

## 1. Install Nix and prepare the checkout

1. Install [Determinate Nix](https://determinate.systems/install/) with the macOS
   package installer and open a new terminal.
2. Clone or update the reviewed checkout at `/Users/nolan/nixos`. OmniWM reads
   `config/omniwm/settings.toml` through a live link to that checkout. When Git
   is missing, use the temporary Nix shell before cloning.

   ```sh
   nix shell 'https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1#git'
   git clone https://github.com/nolvyn/nixos.git /Users/nolan/nixos
   cd /Users/nolan/nixos
   ```

3. On an existing Mac, review the declared Homebrew and App Store packages
   before activation. Add packages you intend to keep because activation removes
   undeclared packages in both managers. List App Store apps with
   `nix shell .#darwinConfigurations.Astraeus.config.programs.mas.package -c mas list`.
   Review agent permission arrays, approval/sandbox policy, model preferences,
   project trust and Remote Control settings. Preserve account data and native
   plugin caches. Never copy sign-in state from another machine or replace a
   native plugin cache with a Nix-store link.
4. Sign in to the Mac App Store as `nolan`. Acquire Xcode and Wuthering Waves
   from the App Store or run the following and complete any Apple Account prompts.
   Reinstallation through `mas install` needs prior acquisition; an app not yet
   acquired shows `No downloads initiated`. Activation never runs `mas update`
   or changes Automatic Updates.

   ```sh
   sudo mas get 497799835 6475033368
   ```

## 2. Build and activate on the Mac

Build as `nolan` to use that user's Git checkout, then activate the built
generation. Use the same sequence for later changes. Review file collisions
before moving existing data.

```sh
nix build .#darwinConfigurations.Astraeus.system
sudo /nix/var/nix/profiles/default/bin/nix-env --profile /nix/var/nix/profiles/system --set ./result
sudo ./result/sw/bin/darwin-rebuild activate --no-flake
```

Log out and back in for a fresh session and to apply any Separate Spaces change.
Use the managed apps. Avoid separate Homebrew or CLT installations, duplicate
app copies, re-signing Brave or OmniWM, and Home Manager `copyApps`.
Homebrew lives at `/opt/homebrew` (nix-homebrew). ChatGPT, Claude Desktop, Steam,
Heroic, CrossOver and NotProton are Homebrew casks with their own updaters;
Prism Launcher comes from Home Manager (`~/Applications/Home Manager Apps`).
The Codex and Claude CLIs stay Nix-managed. Proton Pass desktop is not declared yet.

## 3. Approve apps and sign in

- Open `~/Applications/Home Manager Apps/OmniWM.app` if needed. Approve
  Accessibility and Input Monitoring for the app in System Settings →
  Privacy & Security. Return to OmniWM, recheck permissions, and choose
  **Continue Without Screen Recording** unless you want capture-derived visuals.
  Keep the app's own login item disabled.
- On first Proton VPN connection, accept the VPN configuration. For
  WireGuard, Stealth or Smart Protocol, approve its network extension in
  System Settings → General → Login Items & Extensions → Network Extensions.
  Approve split tunneling separately if used.
- Launch Steam and approve Rosetta when prompted. If NotProton is blocked,
  use Privacy & Security → Open Anyway, then complete its Steam/runtime setup.
  Activate the CrossOver license and select Heroic compatibility runners as needed.
- Sign in to ChatGPT, Claude Desktop (`open -a Claude`), and the apps and game
  stores you use. Verify Claude Remote Control status in Desktop if using it.
  Sign into GitHub via `gh auth login`. Restore browser data, files and game
  saves from your backups or app sync. Review optional app permissions as prompted,
  including Local Network for LocalSend. Browser extensions install by managed
  policy; check `brave://policy` or `chrome://policy` after a restart.
- Check the native plugin inventories with `codex plugin list --marketplace
  home-manager --json`, `claude plugin marketplace list` and `claude plugin list
  --json`. For Codex conflicts, see the Codex plugin rule in `AGENTS.md`.
  If Claude omits a required plugin after initialization, register the
  already-declared directory with `claude plugin marketplace add <directory>` and
  run `claude plugin install <name>@<marketplace> --scope user` for the missing
  entry. Check `android-cli@android-cli-plugin` and `sentry`, `claude-security`
  and `pr-review-toolkit` at `claude-plugins-official`. Authorize Sentry and other
  remote accounts as needed and inspect existing account-synced connections first.
  A marketplace entry is not an installation: check installed and enabled. Use
  the declared directory, not a second clone. A registration error is never a
  reason to replace settings or make them mutable.

## 4. Set up Xcode and project tools

1. Outside project shells, run `open /Applications/Xcode.app` and accept the
   license in Xcode. Run `astraeus-dev-setup` as `nolan` and answer any sudo
   prompt. Clear a conflicting `DEVELOPER_DIR` with `set -e DEVELOPER_DIR` in
   Fish or `unset DEVELOPER_DIR` in POSIX shells. For a different installed
   Xcode, use `astraeus-dev-setup --xcode /Applications/Xcode-beta.app`.
   The helper refuses an unaccepted license and concurrent runs, and never
   deletes, erases, boots or shuts down a simulator. A second run prints the
   same UDIDs.
2. If a compatible registered arm64 iOS runtime is missing, explicitly run
   `astraeus-dev-setup --download-runtime` or install one in Xcode Settings →
   Components and rerun. For a specific installed runtime, use
   `xcrun simctl list runtimes` and pass its identifier to
   `astraeus-dev-setup --runtime <identifier>`. Inspect registered images with
   `xcrun simctl runtime list --json` and available devices with
   `xcrun simctl list devices available`. Record the printed iPhone/iPad UDIDs
   for project use. If a named device conflicts, inspect its UDID in
   CoreSimulator or Xcode → Open Developer Tool → Device Hub where available.
3. Clone or restore your projects under `~/projects` and use their locked shells
   for build tools, SDKs, licenses, signing and acceptance tests. Keep Flutter,
   Android tooling and additional Rust toolchains project-local. Use Swift
   Package Manager where supported, or project-pinned Ruby/CocoaPods if needed.
   For Android CLI, reuse the project SDK with
   `android --no-metrics --sdk=/absolute/existing/android-sdk info` and
   `android --no-metrics --sdk=/absolute/existing/android-sdk emulator list`.
   Check `dart --version` and `android --no-metrics --version` in the selected
   environment. Avoid `android init`, `android update`, a second SDK and
   emulator image downloads for validation.
4. Run the project's build and device checks on the Mac. Boot simulators when
   needed. For physical devices, follow Xcode's account, signing, pairing and
   Developer Mode prompts. Evaluation on Linux proves nothing about native
   builds, signing or devices.

Not needed: MDM, TCC database edits, Full Disk Access workarounds, Terminal
access to browser app data, Intel Homebrew.
