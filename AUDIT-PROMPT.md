# NixOS configuration audit

Read `AGENTS.md` completely first; its safety rules and validation commands
apply in full. Audit both hosts for verified improvements to correctness,
security, recovery, reproducibility, performance, closure size, desktop
usability and maintainability. This prompt grants no permission to fix anything.

## Rules of the audit

- Read-only. Record initial Git status and diffs, preserve staged, unstaged and
  untracked work, and confirm at the end that nothing changed.
- Never read, decrypt, modify or expose contents of `secrets/` or `assets/`.
  Their paths, permissions, persistence, references and deployment are in scope.
- Experiments only to test one hypothesis, in a disposable copy outside the
  repository. Record exact commands and diffs, restore and verify at once, and
  skip any experiment whose restoration or data safety is not guaranteed.
- No activation (`nh os switch`, `nixos-rebuild test`, Home Manager), Disko,
  installer run, garbage collection, destructive Git, input or `flake.lock`
  update, or generated-file change (including `nix run .#write-flake`).
- Treat this as a fresh audit: earlier reports, comments, tests and green
  evaluation are leads, not proof. Read every in-scope file (modules, hosts,
  scripts, Lua, QML, TOML, CSS, templates, docs, input metadata); searches alone
  are not coverage. Trace script consumers, including dynamic imports, before
  calling a file dead. Report once at the end and name every coverage gap.
- Take exact revisions from `flake.lock`. For claims about options, defaults,
  deprecations, security or package behavior, cite primary sources for those
  revisions with version or commit and access date. Check newer upstream
  separately and verify compatibility with the pinned inputs before recommending
  it. Label secondary evidence and uncertainty.

## Checklist

- **Evaluation.** Evaluate both hosts with the bounded commands. Verify Den's
  aspect graph, schema, batteries, overlays, module arguments and Home Manager
  wiring against pinned versions. Look for platform leaks, conflicting or
  ineffective options, removed options, type errors and accidental overrides.
  Check hard-coded users, paths, hostnames, interfaces and devices against the
  schema. Check that inputs, `flake.lock` and generated `flake.nix` agree and
  that `AGENTS.md` still fits the architecture.
- **Security and privacy.** SSH, firewall, kernel/sysctl and systemd hardening,
  Nix trust settings, substituters, signing keys, browser policies and
  network-facing services. agenix recipients, identity paths, ownership and host
  selection, without reading secrets. Exposure from LocalSend, printing,
  qBittorrent, discovery, gaming and AI tools. Credential leakage, insecure
  downloads, mutable executables, unsafe shell expansion, excess permissions and
  secrets entering the store; report redacted file/line evidence only.
  Separate real vulnerabilities from deliberate personal tradeoffs.
- **Publication.** Check staged and untracked candidates against the public-prose
  rule, for account or project details and private temporary paths. State
  current-tree, unpublished and Git-history coverage separately. No credential
  rotation, permission change, history rewrite, commit or push.
- **Storage, boot and recovery.** Disko, Btrfs, impermanence, rollback,
  bootloader, initrd, swap, mount dependencies and hardware modules against the
  maintenance invariants. Trace ordering of mounts, rollback, secret decryption,
  users, networking, display manager and Home Manager. Check persistence of
  SSH/agenix and machine identities, password files, NetworkManager state, app
  data and logs. Name data-loss, boot-failure, lockout and broken-recovery risks.
  Inspect `scripts/nixos-anywhere.sh` without running it: validation, quoting,
  cleanup, key handling, target selection and destructive risk.
- **Reproducibility and cost.** Input pinning, `follows`, overlays, mixed package
  sets, mutable upstream state, duplicated package sets, unneeded services,
  oversized closures and avoidable boot work. Laptop power, firmware, Bluetooth,
  graphics and suspend conflicts. Back performance and size claims with
  measurements; source size alone proves nothing.
- **Desktop.** Hyprland Lua, keybindings, autostart, monitor fallbacks, Hyprlock,
  SDDM, Quickshell QML, Rofi, Kitty, Dunst, Matugen templates, browsers and Home
  Manager links. Verify every referenced command, package, file, icon and path
  on each host; look for startup races, dead keybindings and host-specific
  settings applied globally. Aesthetics are preferences unless they cause a
  concrete usability, accessibility or reliability problem.
- **Maintainability.** Duplicate configuration, stale comments, obsolete options,
  dead code, misleading docs, brittle abstractions, and docs that disagree with
  current inputs, overlays, hosts and aspects. Distinguish installed helpers,
  tests, optional maintenance and unused drafts.

## Method

Inventory Git state, hosts, aspects, inputs and upstream revisions. Build a
shared versus host-specific matrix for WeebMachine and Astraeus and track file
coverage. Trace each suspected issue from source to evaluated or runtime
effect and reproduce it safely where possible. Recheck high-risk findings
adversarially: does a deliberate choice or existing safeguard invalidate them?
Say beforehand when a check needs large downloads. Evaluation is not runtime proof.

## Report

One concise, complete decision document:

1. Summary, scope, coverage gaps, and confirmation of unchanged state and no activation.
2. Ranked findings: severity (Critical/High/Medium/Low/Polish), confidence,
   category, hosts, file/line, evidence or reproduction, version context,
   impact, recommendation, tradeoffs and checks.
3. Unverified concerns needing hardware or runtime investigation.
4. Host validation matrix with measurements.
5. Documentation drift and prioritized choices: fix, defer, investigate or leave.
6. Commands run, experiments, results and cleanup.

Be adversarial but precise. No guesses, subjective preferences or harmless
intentional choices presented as findings. Leave every fix to the owner.
