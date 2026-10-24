# Astraeus manual setup

These are the manual steps for restoring the declared Astraeus environment on
an Apple Silicon Mac. Packages, app links, launchd jobs, browser extension
policies, Fish, and the OmniWM configuration are managed by this repository.
Personal data, account sessions, and Apple security approvals remain outside Nix.
The `workstation` profile provides the portable Home Manager baseline plus shared
applications and tools; Astraeus adds the Determinate, Homebrew, OmniWM, and
mac-app-util foundations and host overrides.

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
   sudo /nix/var/nix/profiles/default/bin/nix-env --profile /nix/var/nix/profiles/system --set ./result
   sudo ./result/sw/bin/darwin-rebuild activate --no-flake
   ```

   Use the same build, set-profile, and activate sequence for subsequent changes.
   Building as your user avoids root's Git ownership check on the checkout;
   activation uses the exact built generation. Inspect any activation collision
   before moving an existing file; do not blindly overwrite it.
5. Log out and back in if separate Spaces changed, and to start a new session
   with Fish and the managed environment. Keep the checkout at the declared
   path: OmniWM reads `config/omniwm/settings.toml` through a live symlink.
   Keep intended settings edits in the repository and commit them.

Homebrew is bootstrapped at `/opt/homebrew` by nix-homebrew. Do not run a separate
Homebrew installer. The declared casks are Proton VPN (`protonvpn`, owned by the
shared `proton` aspect), the official ChatGPT desktop app (`chatgpt`, owned by
`ai.chatgpt`), and CrossOver, Heroic, NotProton, and Steam (owned by `gaming`).
Activation uninstalls undeclared formulae/casks.
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

The shared `gaming` aspect installs Heroic through the `heroic` Homebrew cask at
`/Applications/Heroic.app`, with its native updater left enabled. Heroic is not
also installed through Nix on macOS; Linux installs `pkgs.warm.heroic` as a
NixOS system package, not through Home Manager.
Prism Launcher uses Home Manager's Nixpkgs package and its bundled Java runtime
selection. Launch Prism from `~/Applications/Home Manager Apps`; do not install
a duplicate Prism Homebrew cask.
Game downloads, accounts, saves, and launcher data remain mutable personal state.
Windows-game compatibility runners in Heroic are selected separately as needed.

Steam installs at `/Applications/Steam.app` through Homebrew and retains its
native updater. Its current [Homebrew cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/s/steam.rb)
requires Rosetta on Apple Silicon. Accept Apple's Rosetta installation prompt
when launching Steam if needed; this approval is a manual setup step.

CrossOver and NotProton install through the `crossover` and
`notprotonnot/notproton/notproton` casks. The `gaming` aspect declares NotProton's
upstream tap; it does not run a post-install script. If macOS blocks NotProton's
first launch, approve it in System Settings → Privacy & Security → Open Anyway.
CrossOver license activation and NotProton's Steam/runtime setup remain manual.

Mac App Store apps are owned separately by nix-darwin `programs.mas`. Its desired
set contains Xcode (`497799835`), declared by `dev.darwin`, and Wuthering Waves
(`6475033368`), declared by `gaming.darwin`; the host
owns MAS enablement and cleanup policy. Activation removes undeclared
MAS apps (not built-in macOS apps). Before the first switch on an existing Mac, run
`nix shell .#darwinConfigurations.Astraeus.config.programs.mas.package -c mas list`
and declare any apps you want to retain in `programs.mas.packages`. Sign into the
Mac App Store as `nolan` and acquire declared apps there if needed before
activation can install them.
Activation does not run `mas update` or change Apple's Automatic Updates setting.

## Local development: explicit Apple setup

The `dev` aspect installs Xcode through the existing MAS activation above and
provides `astraeus-dev-setup` through Darwin Home Manager. The App Store selects
the current compatible release; Xcode and Apple's runtimes are not lock-pinned
Nix derivations. Check the installed release and macOS compatibility against
[Apple's Xcode support table](https://developer.apple.com/support/xcode/).
Xcode 27 requires macOS Tahoe 26.6 or later according to its
[release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes).
An older compatible App Store version is not evidence of Xcode 27 readiness.

After the build/profile/activate sequence above has actually installed Xcode,
run these **on Astraeus as `nolan`**, outside any project shell:

```sh
open /Applications/Xcode.app
astraeus-dev-setup
```

Review and accept Apple's license yourself in Xcode. The helper refuses an
unaccepted license. It selects `/Applications/Xcode.app/Contents/Developer` using
`sudo xcode-select --switch` when necessary, verifies the global selection even
if `DEVELOPER_DIR` was set, and runs Apple's `-runFirstLaunch` only after the
license check and only if `-checkFirstLaunchStatus` says it is required. A conflicting
`DEVELOPER_DIR` in your calling shell is refused before changes; remove it with
`set -e DEVELOPER_DIR` in Fish or `unset DEVELOPER_DIR` in a POSIX shell, then rerun.
The helper cannot change its parent shell's environment. Sudo may
prompt for the administrator password. For a deliberately different installed
Xcode, use `astraeus-dev-setup --xcode /Applications/Xcode-beta.app`.
No separate CLT installation, Homebrew Xcode cask, or Xcode downloader is needed.

If no compatible registered runtime exists, explicitly permit a download:

```sh
astraeus-dev-setup --download-runtime
```

This checks CoreSimulator registration first. It reuses the newest available
iOS 26+ runtime no newer than the selected simulator SDK that supports both an
iPhone and an iPad. It correlates the registered runtime with CoreSimulator's
runtime-image metadata by identifier and bundle path, requiring `Ready`,
`Verified`, and advertised `arm64` support. It does not infer guest architecture
from a potentially universal loader binary.
The iOS 26 floor also covers Nemure's AlarmKit requirement. If needed, it asks
Apple's `xcodebuild -downloadPlatform iOS -buildVersion <SDK version>
-architectureVariant arm64` to install the native runtime, then checks registration
again. A successful download alone never counts as success. Runtime availability,
Apple account prompts, network access and free disk space can block installation;
the helper streams setup/download progress and reports the failing command and
Apple's output. Use Xcode Settings → Components to inspect or install a compatible runtime if necessary, then rerun.
See [Apple's component installation documentation](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components).
No runtime download or first-run command is attached to Nix activation or a login job.

The helper reuses an available iPhone/iPad already registered for that runtime,
or creates `Astraeus iPhone iOS <version>` and `Astraeus iPad iOS <version>` using
runtime-supported device types. It reads the devices back and prints confirmed
UDIDs. Repeated runs retain names, boot state and data; concurrent helper runs
are refused. If a helper-named device exists but is unavailable or incompatible,
it stops with that UDID for diagnosis instead of creating duplicates on retries.
It never deletes, erases, boots or shuts down a simulator. Runtime and device state remains in Apple's normal shared per-machine/per-user locations,
so all three projects reuse it. To select a specific installed runtime:

```sh
xcrun simctl list runtimes
xcrun simctl runtime list --json
astraeus-dev-setup --runtime com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl list devices available
xcodebuild -version
xcode-select -p
```

Use the identifier actually listed on the Mac; the example is not a required
runtime version. Save each printed UDID for project commands. Running the helper
once more should print the same UDIDs without creating more devices or downloading
another runtime. Boot and exercise devices only when beginning the corresponding
Mac test session.

[Device Hub ships with Xcode 27](https://developer.apple.com/videos/play/wwdc2026/260/),
not as a separately installed app. It combines physical-device and simulator
inventory, interactive screens, configuration, apps and diagnostics. Open it from
Xcode → Open Developer Tool → Device Hub. Apple's `devicectl` supplies device
inventory/automation; this helper uses `simctl` for CoreSimulator registration.
After installation, inspect the installed tool's capabilities with
`xcrun devicectl help` and `xcrun simctl help`; Device Hub behavior has not been
exercised from Linux.

### Project tools and Android convention

Keep project versions in each app's locked development shell. The shared host
already supplies editor/Fish/direnv integration and general Rust/Python/JS tools;
project shells take precedence for their own Rust targets, Flutter and Dart.
Do not add global Flutter, Android Studio, CocoaPods, or another Rust installer.
Prefer Swift Package Manager where the project's plugin set supports it; if
CocoaPods is required, provide the pinned Ruby/CocoaPods tooling inside that
project shell or Bundler environment, never through `sudo gem install`.

Each project's Darwin shell should provide only its required SDK platform,
build-tools, NDK, JDK and optional emulator/image. Use these shared variable names
**inside the project shell**, without global Fish/session settings:

| Variable | Meaning |
|---|---|
| `ANDROID_HOME` | Project-selected SDK root |
| `ANDROID_SDK_ROOT` | Same SDK root for compatible older clients |
| `ANDROID_NDK_ROOT`, `NDK_HOME` | The project's pinned NDK path |
| `JAVA_HOME` | The project's selected JDK home |
| `ANDROID_AVD_HOME` | Project-scoped writable AVD directory |

Prefer a lock-pinned `androidenv` composition when its Darwin tools are usable;
if the pinned Nixpkgs lacks a usable native emulator, the app worker must provide
an explicit project-local official-tools setup and document its versions and
license step. Never silently fall back to Linux binaries or an Intel guest on
Apple Silicon. Select `arm64-v8a` Android system images and the native Darwin
emulator; keep SDK/NDK inputs separate from mutable AVDs, Pub/Gradle caches and
app data. Use project-prefixed AVD names and project-local caches. Android license
acceptance is a deliberate project setup step, not a global host policy. Do not
apply Linux KVM groups or Linux-only `aapt2` overrides on Darwin.

### Consolidated project handoff and evidence

The actual WeebMachine checkouts inspected for this task are
`/home/weeb/projects/folirei`, `/home/weeb/projects/shiori`, and
`/home/weeb/projects/nemure`; only their app workers may change them. Their flakes,
locks and setup/deployment guidance are independent of this host's lockfile.
Use `/Users/nolan/projects/<name>` on Astraeus, and the commands/checklists delivered
by each app worker after their changes are integrated. The host's `dev` aspect
creates mutable `~/projects`; it does not clone or synchronize application data.

| Project | Inspected starting point | App-worker responsibility / Mac gate |
|---|---|---|
| Folirei | Linux-only flake; Flutter + FRB/Rust; NDK 28.2/JDK 17 Android composition | Add Darwin shell/Apple Rust targets and scoped plugin tooling; preserve build-identity wrappers in `DEPLOYMENT.md`/build guidance. Actual iOS/macOS build and reader behavior remain Mac-only. |
| Shiori | Darwin Rust/Flutter shells declared; Android composition guarded to Linux | Add native Darwin Android tooling/Apple targets and project build/run entry points. Preserve source-validation, renderer/data and accessibility gates. |
| Nemure | Darwin Flutter shell declared; Android build-tools output Linux-only | Supply Darwin Android/JDK tooling and Apple build/run checks. AlarmKit Swift scaffold was explicitly uncompiled/untested; simulator success cannot prove physical alarm reliability. |

This handoff does not deploy Folirei's websites, enable Shiori cloud/sync, pair a
Hue bridge, or run the app repositories' guarded Linux runtime harnesses. Existing
SDK/security holds and project permission/resource rules remain in force.

Linux verification covers bounded host derivation evaluation, Nix syntax/format,
Python checks and mocked setup/idempotency/failure paths. Darwin derivation
evaluation checks module wiring only. **Not run on a Mac:** MAS installation,
Xcode selection/first launch, real runtime download/registration, Device Hub,
project iOS/macOS compilation, native Android builds/emulators, simulator app
launch, VoiceOver, signing or physical-device tests. Confirm those separately;
source preparation is not a claim that the apps now run on Astraeus.

Signing and physical pairing are optional for simulator-only development. For
physical iPhone/iPad runs, add the appropriate Apple account/team in Xcode, follow
its signing/provisioning prompts, pair/trust the device, and enable Developer Mode
on that device when Apple requests it. Do not auto-create certificates, accept
agreements, pair hardware or change host security settings through this helper.
Nemure physical alarm/notification permissions and reliability tests remain
separate app-owned work.

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
- Sign in to Steam and the stores used in Heroic, and add your Microsoft account
  in Prism Launcher when needed. Restore game saves from backups or cloud sync.
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
Terminal access to Brave/Chrome App Data, a separate Apple CLT install, or Intel
Homebrew is required for this configuration. Terminal's temporary browser App
Data access used during migration is not part of fresh setup. Existing grants
can be reviewed in System Settings → Privacy & Security → Files & Folders;
their current state is not reliably established by a permission-free CLI audit.
Do not re-sign the supplied Brave or OmniWM app, enable Home Manager `copyApps`,
or install another copy of OmniWM with Homebrew.
