# NixOS Configuration Full-Repository Audit Prompt

Perform a comprehensive audit of this NixOS configuration repository. The goal
is to identify verified improvements to correctness, security, reproducibility,
reliability, maintainability, boot and runtime performance, closure size,
desktop usability, and confidence that both machines can rebuild successfully.

Before doing anything, read `AGENTS.md` completely and follow it as the
canonical project rules. `CLAUDE.md` only imports `AGENTS.md`; it is not a
separate source of project instructions.

## No autonomous remediation

Do not permanently fix or refactor anything during this audit. The user will
review the final report and decide what should be changed.

Controlled temporary changes are allowed only when they materially help test or
disprove a specific hypothesis. Examples include temporarily changing an option
to reproduce an evaluation failure, creating a minimal test module, or applying
a candidate patch to see whether a check becomes green.

For every temporary experiment:

- Prefer a disposable copy or temporary directory outside the repository.
- Record the repository's initial Git status and existing changes first.
- Keep the experiment narrowly scoped.
- Never stage or commit it.
- Never mix it with pre-existing user changes.
- Record the exact temporary diff and commands used.
- Restore or remove it immediately after the experiment.
- Verify that the repository matches its original state afterward.
- Include useful experimental results in the report, but do not leave the
  candidate fix applied.

If exact restoration cannot be guaranteed, do not perform the experiment.
Never modify, decrypt, replace, or expose anything under `secrets/` or
`assets/`.

At the end, compare the final Git status and diff with the initial state and
explicitly confirm that the audit left no changes behind.

## System safety

Never perform an operation that activates or deploys a configuration:

- Do not run `nixos-rebuild switch`, `boot`, or `test`.
- Do not run Home Manager activation or `nh os switch`.
- Do not run Disko formatting or mounting operations.
- Do not execute `scripts/nixos-anywhere.sh`.
- Do not install, deploy, reboot, repartition, or modify boot state.
- Do not start, stop, restart, enable, or disable system services.
- Do not update flake inputs or `flake.lock`.
- Do not run `nix run .#write-flake`.
- Do not perform garbage collection or destructive Git operations.

Evaluation, syntax checks, non-activating builds, and isolated temporary
experiments are allowed when they cannot alter the running configuration or
user data.

## Current and version-appropriate research

NixOS, nixpkgs, Home Manager, Den, Hyprland, Quickshell, Disko,
Impermanence, agenix, and related projects evolve quickly. Do not rely only on
model memory, old examples, blogs, or general Nix knowledge.

For claims involving current options, defaults, deprecations, security advice,
package behavior, or recommended configuration:

1. Determine the exact revisions used by `flake.lock`.
2. Consult the official documentation, source code, release notes, and option
   definitions corresponding to those locked revisions.
3. Also check the latest official upstream documentation, changelogs, and
   security advisories for relevant changes since the pinned revision.
4. Clearly distinguish:
   - what is correct for the currently locked revision;
   - what changed in newer upstream versions;
   - what is merely a forward-looking recommendation.
5. Never recommend "latest" syntax or behavior without confirming that it
   applies to this repository's pinned inputs.
6. Cite the authoritative source, relevant version or commit, and access date
   for material external claims.

Prefer primary sources: official manuals, upstream repositories, source code,
release notes, option definitions, and security advisories. Use secondary
sources only when primary evidence is unavailable, and label them accordingly.

## Completeness requirement

Audit every in-scope file independently, including Nix modules, host
definitions, shell scripts, Lua, QML, TOML, CSS, templates, generated-file
relationships, documentation, and input metadata.

Treat this as a fresh audit. Do not trust previous audits, audit commits,
existing checks, comments claiming something was verified, or a green
evaluation. Do not stop after finding the first issues or ask whether to
continue. Complete the entire audit and report once at the end.

Encrypted ciphertext and binary assets do not need content inspection, but
their references, paths, permissions, persistence, and deployment behavior
remain in scope.

## Audit scope

### Evaluation and correctness

- Evaluate both `WeebMachine` and `MoeNote`.
- Verify the Den aspect graph, schema, batteries, overlays, module arguments,
  host-specific includes, and automatic Home Manager wiring.
- Check desktop/laptop conditionals and ensure settings cannot leak into the
  wrong host.
- Find conflicting options, ineffective settings, invalid package references,
  removed or renamed options, type errors, accidental overrides, and settings
  that evaluate but will not behave as intended.
- Check for hard-coded usernames, paths, hostnames, interfaces, devices, and
  assumptions that conflict with the schema.
- Verify `modules/inputs.nix`, `flake.lock`, generated `flake.nix`, and
  `AGENTS.md` describe the same configuration.
- Confirm generated files have not drifted from their sources.

### Security and privacy

- Audit SSH, firewall rules, kernel and sysctl hardening, systemd hardening,
  Nix trusted and allowed users, substituters, signing keys, browser policies,
  and network-facing services.
- Review agenix recipients, identity paths, ownership, permissions, and
  host-specific secret selection without decrypting secret values.
- Check Syncthing, LocalSend, printing, qBittorrent, discovery services,
  virtualization, gaming, and AI tools for unnecessary exposure or unsafe
  defaults.
- Look for plaintext credentials, leaked tokens, insecure downloads, mutable
  executable content, unsafe shell expansion, excessive permissions, and
  secrets accidentally copied into the Nix store.
- Distinguish verified vulnerabilities from deliberate personal security
  tradeoffs.

### Storage, boot, persistence, and recovery

- Audit Disko, Btrfs, impermanence, rollback, bootloader, initrd, swap, mount
  dependencies, and hardware modules.
- Verify important system and user state is persisted intentionally while
  temporary state remains ephemeral.
- Check host SSH identities, agenix identities, password files, Syncthing
  identity, NetworkManager state, application data, logs, and machine identity.
- Trace ordering between mounts, rollback, secret decryption, users,
  networking, display management, and Home Manager.
- Identify anything that could cause data loss, boot failure, login lockout,
  broken recovery, or state unexpectedly disappearing after reboot.
- Do not recommend generic hardware rewrites without machine-specific evidence.

### Reproducibility, performance, and closure size

- Audit input pinning, `follows` relationships, overlays, and use of stable,
  warm, unstable, or other package sets.
- Look for duplicate package sets, unnecessary services, redundant
  applications, oversized closures, and avoidable boot-time work.
- Check laptop power-management behavior and possible conflicts involving TLP,
  firmware updates, Bluetooth, graphics, suspend, and desktop services.
- Identify dependencies whose reproducibility or security relies on mutable
  upstream state.
- Do not claim a performance or closure-size problem without measurements or
  clearly labeled supporting evidence.

### Desktop behavior and usability

- Inspect Hyprland Lua modules, keybindings, autostart, monitor fallbacks,
  Hypridle, Hyprlock, SDDM, Quickshell QML, Rofi, Kitty, Dunst, Matugen
  templates, browser configuration, and Home Manager links.
- Verify referenced commands, packages, files, icons, templates, and paths
  exist on every applicable host.
- Check for invalid Lua or QML, startup races, missing binaries, dead
  keybindings, inconsistent paths, and host-specific behavior applied globally.
- Treat aesthetics as preferences unless they cause a concrete usability,
  accessibility, reliability, or consistency problem.

### Maintainability and operational safety

- Find duplicated configuration, stale comments, obsolete options, dead code,
  misleading documentation, inconsistent naming, and brittle abstractions.
- Verify aspects follow the documented Den attrset structure and include only
  the required NixOS, Home Manager, or dependency blocks.
- Check that documentation agrees with current inputs, overlays, hosts, and
  aspect relationships.
- Audit `scripts/nixos-anywhere.sh` without executing it. Review validation,
  quoting, temporary-file cleanup, key handling, target selection, failure
  behavior, and opportunities for accidental destructive use.

## Method

1. Record the initial Git status, diff, repository structure, hosts, aspects,
   inputs, generated files, and available validation tools.
2. Determine the exact locked revisions of important upstream projects.
3. Build a `WeebMachine` versus `MoeNote` matrix showing shared and
   host-specific configuration.
4. Read every in-scope file; searches and successful evaluation alone do not
   count as full coverage.
5. Trace each suspected issue from source configuration to evaluated or
   runtime effect.
6. Reproduce or otherwise verify findings when safely possible.
7. Use isolated temporary experiments when they substantially improve
   confidence, then restore the baseline immediately.
8. Label uncertain concerns as unverified rather than reporting them as facts.
9. Perform a second adversarial pass over high-risk areas.
10. Confirm that the final repository state exactly matches the initial state.

## Safe validation

Run evaluation with lock-file updates disabled:

- `nix flake check --no-update-lock-file`
- `nix eval --no-update-lock-file .#nixosConfigurations.WeebMachine.config.system.build.toplevel.drvPath`
- `nix eval --no-update-lock-file .#nixosConfigurations.MoeNote.config.system.build.toplevel.drvPath`

Use non-formatting syntax checks for shell, Lua, QML, TOML, and other formats
when the required tools are available.

Non-activating builds may be used when needed:

- `nix build --no-link --no-update-lock-file .#nixosConfigurations.WeebMachine.config.system.build.toplevel`
- `nix build --no-link --no-update-lock-file .#nixosConfigurations.MoeNote.config.system.build.toplevel`

State beforehand if a validation requires a large download or substantial
resources. If a check cannot be run, report the exact reason and the command
that remains.

## Final report

Return one final report containing:

1. An executive summary and explicit confirmation that no temporary changes
   remain and no configuration was activated.
2. A ranked findings table with:
   - ID
   - Severity: Critical / High / Medium / Low / Polish
   - Confidence: High / Medium / Low
   - Category
   - Affected hosts
   - File and line
   - Evidence or reproduction
   - Relevant locked and latest-upstream version context
   - Impact
   - Recommended change
   - Risks and tradeoffs
   - Suggested verification
3. A separate section for unverified concerns that require hardware or runtime
   testing.
4. A `WeebMachine` versus `MoeNote` configuration and validation matrix.
5. Security, persistence, recovery, reproducibility, performance, and closure
   observations, with measurements where available.
6. Documentation drift and remaining validation gaps.
7. A prioritized decision list so the user can choose what to fix, defer,
   investigate, or intentionally leave unchanged.
8. Every command run, every temporary experiment performed, and its cleanup
   status.

Be adversarial but precise. Do not inflate the report with guesses, subjective
preferences, or harmless intentional choices. The goal is a verified,
current, actionable decision document—not autonomous remediation.
