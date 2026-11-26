# NixOS configuration working rules

Keep these rules current when architecture or maintenance contracts change.
Deferred work belongs in `TODO.md`, Mac setup in `docs/astraeus-manual-setup.md`.

## Safety

- Preserve existing staged, unstaged and untracked work. Record Git status before
  edits. Ask before deleting files. Stage reviewed paths or hunks only. Commit
  and push only with explicit approval for the respective action.
- Never touch `secrets/`; never decrypt or print sensitive values. Review staged
  diffs and metadata before publication. Keep handoffs, task IDs, private project
  details and conversational approvals out of public files.
- Use bounded, sequential evaluations with lock updates disabled. Flake checks
  and builds are allowed. Activation requires separate approval.

  ```sh
  timeout --signal=TERM --kill-after=5s 45s nice -n 10 nix eval --no-update-lock-file --raw .#nixosConfigurations.WeebMachine.config.system.build.toplevel.drvPath
  timeout --signal=TERM --kill-after=5s 45s nice -n 10 nix eval --no-update-lock-file --raw .#darwinConfigurations.Astraeus.config.system.build.toplevel.drvPath
  ```

- Evaluate the system derivations only. Use an explicit `path:` source for
  required unindexed files. For a bug fix, show a focused regression fails before
  and passes after. Check observable outcomes and report coverage gaps. Test
  counts, source-string checks and mocks alone do not prove runtime behavior.
- Fix the underlying cause. Never mask an error, relax a safeguard or bypass a
  guard to make a build pass.

## Den and flake structure

- Edit inputs in `modules/inputs.nix` or the owning aspect, then generate
  `flake.nix` with `nix run .#write-flake`; never edit it by hand. Change inputs
  only as requested.
- `import-tree` discovers modules except paths containing `/_`. Import those
  helpers explicitly and keep the discovery rules. Keep features, profiles and hosts in their corresponding
  aspect directories and schema/setup in `modules/schema.nix` and `modules/setup.nix`.
  A complete host needs more than the portable base.
- Use `den.aspects`, `den.schema`, `den.default` and `den.policies`, never
  `den.ctx` or `specialArgs`. Omit unused blocks. Use
  attrset-form aspects ordered `nixos`, `darwin`, `homeManager`. Give flat
  module arguments `...` and use the existing `inputs` argument.
- Den wires Home Manager automatically through `classes = [ "homeManager" ]` and
  defines users, home paths, hostnames and shells; do not import its module or
  repeat those settings. Use schema host values. Desktop relative links assume
  `~/nixos`. Guard Home Manager settings with
  `pkgs.stdenv.hostPlatform.isLinux`/`isDarwin`; reserve `host.class` for early
  schema, policy and import decisions. Keep Linux services and persistence
  NixOS-only.
- Alphabetize set-like lists and preserve overlay and override precedence. Keep
  application package, persistence and policy together, with longer optional
  policies last. Preserve state versions across input updates.

## Maintenance invariants

- Keep rollback checkpoints complete and readonly, with per-node identities.
  Allocate both restore trees before moving live roots. Preserve distinct
  observed versions and sole parked data. Retired transactions cannot restore
  live roots. Never consume unresolved checkpoints. Keep mount ordering, failure
  fallback and quota guards. Keep pruning confined to eligible archive names and
  boot independent of rollback success. Qualify old-script fallback and pressure
  in disposable Btrfs guests.
- Keep `/tmp` root-backed. Keep persistence reports read-only and report history
  private. Incomplete scans, missing mounts and old timestamps never authorize
  deletion.
  Never rerun Disko on an existing installation. Keep the installer unpinned and
  its fail-on-drift SSH override. Inspect the target and confirm erasure.
- App confinement toggles default to off and need separate approval; direct-file
  confinement is not full IPC, credential or network isolation. Preserve native
  sandboxes, drift assertions, compatibility overrides, trust, permissions,
  fonts, links, dormant opt-ins and hardware/retention policy unless the task
  authorizes a change. Requalify policy/package/kernel changes.
- Keep Blender's single pinned registration, stable launcher, loopback, safety
  and privacy controls and mutable-cache ownership. Run its guard before cache
  cleanup and `writeBoundary`. Preserve cache collisions and saved preferences.
- Blender's `mcp-for-blender` is the only Nix-declared Codex plugin: Home
  Manager publishes its alias under `~/.local/share/codex-plugins`, Codex
  installs it into its own mutable cache, and `scripts/codex-local-source.nix`
  keeps Home Manager from deleting that cache. The guard accepts only owned
  links, so a failed activation can be retried. Save the native cache before
  rolling back to an older generation. Other plugins install through Codex into
  the persisted `~/.codex`.
- Keep macOS `linkApps` collision checks. Keep licenses, downloads and sign-ins
  manual. Preserve app databases, profile data and native security permissions.
  Switching to `copyApps` requires a separate TCC/App Management decision.
