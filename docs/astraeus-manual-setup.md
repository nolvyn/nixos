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
Use `/Users/nolan/projects/<name>` on Astraeus with each exact published branch
specified below. The host's `dev` aspect creates mutable `~/projects`; it does not
clone or synchronize application data. After `gh auth login`, clone only the
repositories that are absent:

```sh
gh repo clone nolvyn/folirei /Users/nolan/projects/folirei
gh repo clone nolvyn/shiori /Users/nolan/projects/shiori
gh repo clone nolvyn/nemure /Users/nolan/projects/nemure
```

Before switching an existing checkout, inspect `git status --short` and preserve
its local work. No reset, forced checkout or cleanup is part of this handoff.
The app commit links identify the reviewed preparation even if a branch later
advances. Published source and evaluated shells do not establish Mac execution.

| Project | Published preparation | Verified evidence / remaining Mac gate |
|---|---|---|
| Folirei | Pushed on `chore/astraeus-darwin-2026-10` at [`97f6937`](https://github.com/nolvyn/folirei/commit/97f69371b3e1736927f3327d2a1c228febdcf2d7), not `main`; Apple targets, scoped CocoaPods and optional ARM64 Android, with pins unchanged | 29 lightweight controls, Linux/Darwin evaluation and independent review passed; the final ordinary hook passed strict clippy, 2,732 Rust tests, Flutter analysis, 2,342 VM tests, 177 browser tests and Deno/policy gates. Native Mac/iOS/Pods/signing/Darwin Android remain unverified. |
| Shiori | Pushed on `codex/shiori-astraeus-darwin` at [`59f79cb`](https://github.com/nolvyn/shiori/commit/59f79cb10a660a9b9ec2e0a701d24168a3de2ece), not `main`; new Apple runners/FRB Pods wiring and Darwin Android/ARM64 AVD helper | Offline Linux/Darwin shell evaluation, fourteen fixture/evaluation controls, shell/Nix checks, 17 XML/plists, spec validation and independent review/secret scan passed. Native compilation/linkage, Pod locks, signing/VoiceOver and Android ARM execution remain unrun. |
| Nemure | Prepared at [`21b1e47`](https://github.com/nolvyn/nemure/commit/21b1e47e0e90fc979832eecdcbc0dc4332c08f49): matched Flutter 3.44.4/Dart 3.12.2 Apple Silicon shell; optional native Android shell | 175 Python and 288 Dart/Flutter tests plus analysis/format, three-platform shell evaluation and independent review passed on Linux. No native Mac build; AlarmKit remains disabled/uncompiled, signing pending and affected-platform SDK hold unresolved. |

#### Folirei — use the preparation branch

The verified published preparation is
[`97f69371b3e1736927f3327d2a1c228febdcf2d7`](https://github.com/nolvyn/folirei/commit/97f69371b3e1736927f3327d2a1c228febdcf2d7)
on `chore/astraeus-darwin-2026-10`. **It is not on `main`.** From a clean first
clone, select that branch explicitly:

```sh
cd /Users/nolan/projects/folirei
git fetch origin
git switch --track origin/chore/astraeus-darwin-2026-10
git rev-parse HEAD
```

If the local branch already exists, use `git switch chore/astraeus-darwin-2026-10`
and `git merge --ff-only origin/chore/astraeus-darwin-2026-10`; stop on divergence
and preserve local work. The final publication passed the ordinary pre-push hook
without bypass; the original dirty worktrees were preserved.

The exact [command guide](https://github.com/nolvyn/folirei/blob/97f69371b3e1736927f3327d2a1c228febdcf2d7/docs/development/astraeus.md)
and [validation report](https://github.com/nolvyn/folirei/blob/97f69371b3e1736927f3327d2a1c228febdcf2d7/docs/development/astraeus-validation.md)
distinguish initial preparation from later Linux publication checks. The pinned Darwin
outputs retain Flutter 3.41.9 / Dart 3.11.5, Rust 1.96.0, FRB codegen 2.12.0,
CocoaPods 1.16.2 and production wasm-bindgen 0.2.106. CocoaPods is scoped to the
project shell because the existing Cargokit Rust plugin and other plugins need
it; no global SPM toggle or dependency upgrade was introduced. Podfiles/config
includes and Apple Rust targets are prepared, while first native pod locks must
be generated and reviewed on the Mac.

After the shared Apple setup, these are **future Astraeus commands**, not Linux
commands or native-build evidence:

```sh
cd /Users/nolan/projects/folirei
nix develop
python3 scripts/apple-dev-check.py
cd app
flutter pub get --enforce-lockfile
cd ..
python3 scripts/apple-dev-check.py --prepare
flutter doctor -v
flutter devices
scripts/build-macos.sh --debug
scripts/build-ios.sh --simulator --debug
cd app
flutter run -d <device-id>
```

The explicit `--prepare` resolves the committed Dart lock offline and invokes
Flutter's config-only CocoaPods integration; it is not native compilation.
The build wrappers preserve the existing build identity/Sentry definitions.
Choose the shared simulator UDID. Physical signing remains a separate Xcode
step; minimum targets remain iOS 13.0 and macOS 10.15. Apple reader behavior,
including WKWebView, is not established by the Linux controls.

Optional Android build tools require personally reviewing the Android license,
then entering a separate project shell from the project root:

```sh
NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1 nix develop --impure .#android
adb devices
scripts/build-apk.sh --debug
```

The separate `.#androidEmulator` shell additionally requires reviewing the ARM
image license. It provides one API-36 `google_apis/arm64-v8a` image and emulator
36.5.11. Build tools retain platforms 33–36, build-tools 35.0.0, NDK
28.2.13676358, CMake 3.22.1 and JDK 17. Follow the project guide's create-once
`folirei-api36-arm64` AVD instructions, preserving any existing AVD; SDK and AVD
state remain separate. No SDK realization, license acceptance or guest boot was
performed during preparation. The affected-platform Dart SDK hold remains;
preparing an Android command does not establish Android security clearance.

Web commands in the project guide require a deliberately selected installed
native Chrome executable through `CHROME_EXECUTABLE`. No Darwin browser build,
reader parity or replacement for the Linux resource harness is claimed.

The owning worker's final Linux publication report records both strict clippy
gates, 2,732 Rust tests (five ignored), 13 Python controls, Flutter analysis with
zero issues, 2,342 VM tests (four skipped), 177 browser tests, Deno lint/typechecks
and seven final policy controls passing through the complete ordinary hook.
Short temporary paths, a private test D-Bus and the actual Chromium run were
validated; cleanup retired 234 tracked identities, left no reservations and
preserved protected processes. Earlier interrupted attempts remain failed
attempts, not omitted tests or a hook bypass.

The exact process-local Linux tooling trust mitigation was verified on that
host. It is not an SDK upgrade or Android/Windows advisory clearance. Native
Mac/iOS builds, CocoaPods resolution/locks, signing, Darwin Android and built
reader/Patrol acceptance remain unrun; earlier reader/audio qualification
failures are not resolved by the Linux hook pass.

#### Shiori — use the preparation branch

The verified published source is
[`59f79cb10a660a9b9ec2e0a701d24168a3de2ece`](https://github.com/nolvyn/shiori/commit/59f79cb10a660a9b9ec2e0a701d24168a3de2ece)
on `codex/shiori-astraeus-darwin`. **It is not on `main`.** The
[exact project report and commands](https://github.com/nolvyn/shiori/blob/59f79cb10a660a9b9ec2e0a701d24168a3de2ece/docs/experiments/reports/PROGRAM-ASTRAEUS-DEVELOPMENT-PREP-001.md)
are authoritative for this preparation. Preserve any existing local changes;
for the first setup from a clean clone, select its branch explicitly:

```sh
cd /Users/nolan/projects/shiori
git fetch origin
git switch --track origin/codex/shiori-astraeus-darwin
git rev-parse HEAD
```

If that local branch already exists, use `git switch codex/shiori-astraeus-darwin`
and `git merge --ff-only origin/codex/shiori-astraeus-darwin`; stop on divergence
and preserve local work. The reviewed commit above identifies
this handoff even if the branch later advances. Access to the pinned private
`nolvyn/epub-rs` engine uses the user's normal Git authentication.

The pins remain Flutter 3.44.4 / Dart 3.12.2, Rust 1.95.0 and FRB 2.12.0.
The project Darwin shell supplies scoped CocoaPods for its Rust precompile/loader
path; no global Flutter SPM preference is changed. Apple runners and bounded
Swift document handling are source preparation, not compilation or usability
evidence. After the shared Apple setup, these are **future Mac checks**:

```sh
nix develop .#flutter
xcode-select -p
xcrun --sdk macosx --show-sdk-path
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk iphonesimulator --show-sdk-path
flutter doctor -v
cd apps/reader-app-flutter
flutter pub get --enforce-lockfile
flutter devices
flutter build macos --debug --no-pub
flutter build ios --simulator --debug --no-pub
flutter build ios --debug --no-codesign --no-pub
flutter run -d macos --no-pub
flutter run -d DEVICE_ID --no-pub
```

Replace `DEVICE_ID` with a listed shared simulator/device UDID. First native
resolution needs network/cache availability; review and commit the generated
Apple `Podfile.lock` files after successful resolution. No resolved native locks
were invented on Linux. Source floors remain macOS 10.15 / iOS 13; physical
signing/provisioning, VoiceOver and real reader/document-provider acceptance
remain Mac gates.

Shiori's Darwin `.#flutter` and default shells are Apple/web only: they exclude
Android SDK/NDKs/JDK/images, Android hooks and Flutter Android engine artifacts.
Linux's existing Android-enabled Flutter shell remains unchanged. To opt into
Android on Astraeus, exit the Apple shell, return to the repository root, review
the SDK and Google APIs ARM image agreements, and only if you agree enter:

```sh
SHIORI_ACCEPT_ANDROID_LICENSES=1 nix develop --impure .#flutter-android
```

The exact acknowledgment and `--impure` are both required. Without them the shell
refuses before forcing the SDK graph. No SDK realization or license acceptance
occurred during preparation. The optional Android shell provides Darwin
platforms 35/36, build-tools
35.0.0, NDK 27.2.12479018 plus 28.2.13676358, CMake 3.22.1, JDK 17 and emulator
36.5.11 with one API-35 `google_apis/arm64-v8a` image. From the repository root
inside the explicitly acknowledged Android shell, AVD preparation is:

```sh
bash tools/setup-reader-android-avd.sh
emulator -list-avds
```

The helper creates/reuses only its marked project-private
`shiori_api35_arm64` guest and refuses foreign, partial, changed, symlinked or
concurrent state. It does not accept licenses, boot guests or remove existing
state. The project report contains deliberate emulator/build/run commands;
Android ARM execution, native NDK behavior and required licensing remain
operator checks. The affected-platform SDK hold is unresolved. Existing web
commands remain available with an installed native browser, but Apple browser,
WASM transport and accessibility runtime behavior were not tested here.

#### Nemure

The prepared source commit is
[`21b1e47e0e90fc979832eecdcbc0dc4332c08f49`](https://github.com/nolvyn/nemure/commit/21b1e47e0e90fc979832eecdcbc0dc4332c08f49),
pushed to private `main` and `chore/astraeus-development`. Follow its
[exact project guide](https://github.com/nolvyn/nemure/blob/21b1e47e0e90fc979832eecdcbc0dc4332c08f49/docs/astraeus-development.md)
for current setup and acceptance details. The default shell provides Flutter
3.44.4, matching Dart 3.12.2 and JDK 21 with guarded project caches. Nemure's
current AlarmKit source requires Xcode 26.1+; deployment targets remain iOS 26.0
and macOS 10.15. Existing SPM integration remains; no CocoaPods, Rust or web
target was added. This preparation is available on `main`:

```sh
cd /Users/nolan/projects/nemure
git fetch origin
git switch main
git merge --ff-only origin/main
git rev-parse HEAD
```

Stop on divergence and preserve local work; the reviewed published commit is
`21b1e47e0e90fc979832eecdcbc0dc4332c08f49`.

After the shared Apple setup, run these **on Astraeus**, from the project checkout:

```sh
cd /Users/nolan/projects/nemure
nix develop
scripts/flutter-local --version
scripts/dart-local --version
for package in packages/nemure_core packages/nemure_hue; do
  (cd "$package" && ../../scripts/dart-local pub get --enforce-lockfile)
done
(cd app && ../scripts/flutter-local pub get --enforce-lockfile)
scripts/check.sh
cd app
../scripts/flutter-local build macos --debug --no-pub
../scripts/flutter-local build ios --simulator --debug --no-codesign --no-pub
../scripts/flutter-local devices
../scripts/flutter-local run -d <chosen-simulator-or-device-ID> --no-pub
```

Choose the shared simulator UDID printed by `astraeus-dev-setup`; the placeholder
must be replaced. The commands above are prepared Mac checks, not Mac execution
evidence. Physical devices additionally require deliberate signing/pairing.
AlarmKit remains disabled and its Swift source uncompiled/untested; missing
countdown Live Activity and lifecycle acceptance still block a usable iOS alarm.
macOS offers alarm management/previews, not autonomous delivery.

For optional Android tools, exit the default development shell and return to
the project root. Personally review the SDK and ARM emulator licenses first:

```sh
cd /Users/nolan/projects/nemure
NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1 nix develop --impure .#android
python3 scripts/setup-android-darwin.py --check --with-emulator-image
python3 scripts/setup-android-darwin.py --create-avd
```

This selects command-line tools 20.0, platform-tools 37.0.0, build-tools 36.0.0,
platforms 35/36, NDK 28.2.13676358, emulator 36.6.11, JDK 21 (Zulu 21.0.11 on
Darwin) and one API 35 `google_apis/arm64-v8a` image. The explicit helper reuses
its matching project-local `NemureArm35` AVD and refuses partial/foreign state;
it does not download tools, accept licenses or launch a guest. See the project
guide for optional emulator/build/run commands and cache boundaries.

Nemure's pinned Flutter/Dart still has the affected-platform SDK hold described
in its [dependency notes](https://github.com/nolvyn/nemure/blob/21b1e47e0e90fc979832eecdcbc0dc4332c08f49/docs/dependency-refresh-2026-10.md).
These future Mac commands do not authorize online affected-SDK tooling on Linux.
No SDK download, license acceptance, native build or device test was performed
for this preparation.

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
