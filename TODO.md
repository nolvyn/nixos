# Deferred Work

These items were intentionally deferred after the repository audit. They are
not authorization to make changes automatically; review each item before
implementation.

1. **Installer, Disko, impermanence, and recovery safety**
   - Test the fresh-install SSH/age identity bootstrap in a disposable VM.
   - The installer now binds disk inspection and upstream SSH transports to the confirmed
     ED25519 key, and stages the recovery identity in `/persistent/etc/ssh` for agenix.
     Verify the complete pre-kexec/post-kexec installation and first login in a disposable VM.
   - Exercise the installer's fingerprint and destructive disk confirmation checks in a disposable VM.
   - The automated disposable-VM test passed real Btrfs archival, nested-subvolume cleanup,
     legacy grace, old-mtime retention, directory/symlink exclusions, and repeated rollback.
     Test the remaining failure recovery and boot-time integration in a disposable VM.
   - Retention now starts at archival and lasts 30 days, independently of live mtimes.
     Legacy-name migration and nested-subvolume deletion are now verified on real Btrfs;
     low-space/failure behavior still needs the disposable VM before a recovery installation.
   - Do not change or exercise these paths on either real machine without a reviewed recovery plan.

2. **Future cross-host synchronization scope**
   - Decide which folders, if any, should be shared between WeebMachine and Astraeus.
   - Keep host keys and other recovery credentials out of ordinary peer synchronization unless separately encrypted.

3. **Future synchronization implementation**
   - Choose a synchronization tool and decide whether its index/database should persist once the sharing scope is settled.
   - Keep declarative configuration and any secret-provided identity separate from rebuildable indexes.

4. **SDDM service ordering**
   - The current `mkForce` ordering was added for a previously observed problem; keep it until that
     behavior can be reproduced safely.
   - When investigating, compare the effective unit with the upstream `systemd-logind` and Plymouth
     ordering and test repeated cold boots before changing it.

5. **Pin mutable AI and MCP tools**
   - Pin the versions used by `npx`, `uvx`, and mutable GitHub invocations.
   - Include the mutable OpenCode plugin and the GitHub flake invocation in `.mcp.json`.
   - Preserve a deliberate update process for security fixes.

6. **Swap, Zram, and hibernation**
   - WeebMachine's inspection found roughly 64 GB RAM, ample available memory,
     no current memory pressure, and no OOM messages in the readable boot logs.
     Astraeus runtime assessment remains deferred to a native maintenance session.
   - Implemented in the existing `optimizations.nixos` block: one Zstd Zram swap device capped at 8 GiB of logical
     capacity, without disk writeback or changes to swappiness. This allocates
     compressed RAM on demand; it does not reserve 8 GiB of physical RAM.
     The configuration was tested in a disposable VM and is ready for a future
     normal deployment; the running host was not activated during this work.
     Disk-backed swap remains a separate decision if sustained workloads need it.
   - Do not add hibernation until its interaction with encryption and the current kernel-security settings is designed.

7. **Gaming-specific laptop configuration**
   - Revisit Steam keybindings, workspace rules, and packages if a future laptop is intended for gaming.
   - The currently shared rules do not require immediate changes.

8. **Core-dump retention**
   - The approved limits are implemented: 1 GiB total, 1 GiB per dump/processing,
     and seven days by modification time. Normal crash-dump creation and the
     six-day/eight-day retention boundary passed a disposable VM test.
   - Verify the limits after a future normal deployment. The running machine was
     not activated or cleaned during this follow-up. Systemd can temporarily
     exceed its aggregate limit while processing a dump.

9. **AppArmor runtime verification**
   - AppArmor applies only to WeebMachine; Astraeus has separate macOS protections.
   - The old configuration enabled AppArmor but declared no policies to load.
     The new `nixos-ping` policy explicitly confines the underlying iputils executable.
     A disposable VM verified attachment in enforce mode, ordinary-user IPv4/IPv6
     and DNS use, blocked private-file reads and unrelated writes, and an
     unconfined control proving the same probe could otherwise perform those accesses.
   - Verify host attachment after a future normal deployment, then consider broader
     applications individually. The global runtime profile inventory requires
     privileged access unavailable during this investigation.
   - Do not bulk-load desktop profiles merely to obtain confined-looking labels;
     some packaged profiles explicitly allow everything.
   - The printing aspect now supplies an enforced Avahi service policy adapted
     from the packaged profile. The service explicitly selects it and is ordered
     after the policy loader; loading the policy alone did not attach it in the VM.
     Policy changes trigger a service restart during a future normal deployment.
     Two disposable VMs verified enforced attachment, printer-service publication
     and discovery in both directions, hostname resolution, service restart, and
     denial of unrelated private-file reads and writes under the selected policy.
     This checks network discovery, not a physical printer or a print job.

10. **Build-artifact growth under `projects/`**
    - Rust and Flutter build output reached roughly 389 GB across two repositories before a manual
      cleanup on 2026-07-30. Nothing bounds it today, so it will accumulate again.
    - Research a durable approach before committing: a shared `CARGO_TARGET_DIR`, `sccache`, and
      `cargo-sweep` on a timer address different parts of the problem and are not interchangeable.
    - The two repositories have different causes. One accumulated duplicate dependency trees across
      many target directories; the other accumulated incremental artifacts in a single one. Dev-profile
      debuginfo settings are likely relevant to the second.
    - A shared target directory introduces cargo lock contention between concurrent builds and makes
      `cargo clean` all-or-nothing across projects. Evaluate that cost before adopting it.
    - Follow-up inspection found about 66 GB in the examined Rust target directories.
      Several roots belong to genuinely separate workspaces/FFI integrations;
      treating all of them as accidental duplicates is not justified.
    - An isolated synthetic Cargo 1.95 trial confirmed that `build.build-dir` with
      `{workspace-path-hash}` relocates intermediates while preserving final
      `target/debug` binaries. Reducing development debug information from 2 to 1
      reduced intermediate allocation from about 51 MiB to 32 MiB in that trial;
      this is a mechanism check, not a benchmark of either real application.
      Disabling incremental compilation reduced it further but slowed the trial's rebuild.
    - Prefer project-specific `profile.dev.debug = 1` trials while retaining
      incremental compilation, followed by per-workspace cache relocation only
      after Flutter/FFI, editor, debugger, and executable-path integration checks.
      Do not change every project's debugger behavior through a global override.
    - Cargo's automatic global-cache cleanup does not cover build artifacts.
      `cargo-sweep` now declares itself unmaintained; do not add it to a cleanup timer.
      `sccache` requires disabling Rust incremental compilation and does not cache
      linker-producing crates such as `cdylib`, so it is not a universal solution here.

11. **Persistent-store visibility and orphan handling**
    - Nothing in this configuration ever deletes from `/persistent`. The rollback service touches only
      `@`, `@home`, `@old_roots`, and `@old_home_roots`; `@persistent` is never referenced. The store
      grows monotonically for the life of the machine.
    - Two distinct failure modes were observed on 2026-07-30, and they need different treatment:
      - *Orphans*: entries removed from the persistence list leave their data behind indefinitely.
        Commenting out an entry removes the bind mount, not the bytes. `sleepy-launcher` (77 GB) and
        `honkers-railway-launcher` (94 GB) survived months and several reboots this way, invisible from
        the live home because the mount was gone while the data was not.
      - *Unbounded declared growth*: `projects/` is correctly declared and reached 595 GB. An
        orphan detector is blind to this by definition, so orphan tooling alone addresses the smaller
        half of the problem.
    - Upstream offers nothing here. The nix-community impermanence module has no cleanup mechanism,
      the NixOS wiki does not discuss store growth, and the existing community tooling
      (impermanence issue #240) solves the inverse problem of finding files that *should* be persisted.
      Letting the persist store grow unbounded appears to be the de facto norm rather than a
      deliberate practice.
    - Automated deletion is the obvious idea and carries real risk here. The most reliable orphan
      signal is "not currently bind-mounted", which inverts dangerously on any boot where the
      configuration only partially applied: every entry looks orphaned at once. This repository has
      already undergone two impermanence refactors where entries were in motion between files. Any
      implementation needs a sanity guard that refuses to act when an implausible share of entries
      appear orphaned simultaneously, and treats that as an alert instead.
    - The failure being corrected is absence of visibility, not absence of automation. Once the numbers
      were surfaced, the disposition decisions took seconds. Prefer reporting first: orphaned paths plus
      top directories by size with week-over-week deltas, which covers both failure modes at zero
      deletion risk. A report nobody reads is worthless, so delivery matters more than detection
      logic; a shell-greeting line or a push notification are both viable.
    - Defer any deletion policy until roughly a month of reports exists. Choosing a policy now means
      choosing one for data never actually observed. If orphans prove recurrent, a quarantine scheme
      (move aside, delete after a delay, restore by moving back) is the next step and the reports will
      have supplied real thresholds.
    - Splitting the persistence root into precious and bulk halves was considered and deliberately not
      pursued yet. It would make aggressive automatic deletion safe on the bulk half, but it is a
      ~590 GB migration, it does not help `projects/` because that is precious and stays unbounded, and
      several real entries are genuinely mixed (`.config/heroic` holds both settings and a large cache).
      Revisit as its own decision, not as an extension of a cleanup pass.
    - Follow-up metadata inspection found roughly 19 GB in unmounted home paths:
      about 9.1 GB under cache directories and 9.9 GB in other data. The cache
      category is a review shortlist, not blanket deletion authorization; one
      cache had recent timestamps. Most large inspected candidates were months old.
      Browser profiles, Wine state, Trash, Documents, and tool configuration remain
      preserve-first candidates because some are absent from the live home.
      Symlinks, protected directories, and unreadable metadata were excluded.
    - The formerly large orphaned launchers now contain only roughly 24 MB combined.
      Most current readable growth is in declared Steam and projects data, including
      scientific datasets and virtual-machine images. Keep that distinct from disposable
      build output; neither directory age nor an absent mount proves safe deletion.

12. **Astraeus reproducibility follow-up**
    - Keep the mac-app-util Tahoe icon source pin and modern SBCL wrapper until an
      equivalent upstream fix can be verified on the Mac; OmniWM is deliberately
      pinned to the validated v0.7.6 release.
    - Retire Astraeus's local MAS module patch once nix-darwin validates numeric
      app IDs instead of treating diagnostic output as installed applications.
    - Homebrew taps/cask versions and managed Web Store extension payloads remain
      mutable. Version pinning beyond the current Nix lock is a separate decision;
      mutable AI/MCP tools are already tracked above.
    - The Phase 7 audit found old `ipc.sock` and `ipc.sock.secret` files in
      `~/Library/Caches/com.barut.OmniWM`; the declared 0.7.6 process will use only
      `~/Library/Application Support/com.barut.OmniWM/ipc.sock`. Leave the old
      files until cleanup is explicitly requested; do not touch the live socket.
    - Review any remaining temporary Terminal browser App Data grants in System
      Settings. Chrome's protected External Extensions directory was not readable
      during the audit; the evaluated configuration creates no extension files
      there, and the prior migration reported all eight legacy symlinks removed.
      Do not grant extra access just to inspect it.
    - Future WeebMachine/Astraeus synchronization, optional Screen Recording, and MDM
      experimentation remain outside this audit's implementation scope.

13. **Runtime checks after audit fixes**
    - Run native Darwin build checks during the next Astraeus maintenance session;
      this Linux audit verified its bounded system derivation evaluation only.
    - After a future normal deployment, verify printer queues survive rollback and a test
      page prints; do not send a print job or change the running machine just for this audit.
    - Verify GitHub CLI account selection/keyring login survives rollback with the real user
      profile, and the Quickshell bar renders normally in a fresh desktop session.
    - These checks are deferred; automated fixtures and builds do not prove hardware behavior.

## Intentional decisions

- Install targets are expected to use NVMe storage, so Disko intentionally retains
  `/dev/nvme0n1`; the installer requires an explicit inspection and erase confirmation instead.
- `nixos-anywhere` intentionally remains unpinned to avoid a manual update workflow. The installer
  therefore trusts its upstream GitHub default branch at execution time. The local package override
  requires exactly one matching SSH argument declaration before replacing insecure host-key defaults;
  upstream changes to that seam stop the build for review instead of silently dropping authentication.
- The 512 MiB ESP and `boot.loader.systemd-boot.configurationLimit = 50` remain unchanged because
  observed use has been acceptable; the limit bounds boot entries only, not store contents. Revisit
  only if `/boot` usage begins growing materially or an installation fails.
- Generation retention was tightened on 2026-07-30 from `--keep 25 --keep-since 30d` to
  `--keep 10 --keep-since 20d` after the store reached 161 GB across 42 generations. Roughly three
  weeks of rollback history is intended; widen it again if a rollback older than that is ever needed.
- Broad AI-agent shell and repository permissions are intentional. Mutable AI/MCP dependencies remain
  deferred above, but the permissions themselves should not be narrowed without a separate decision.
- The packages in `workstation` are intentionally shared by both machines; the
  portable `base` profile and role-specific profiles keep future servers from
  inheriting workstation applications. Closure size alone is not a reason to split
  the workstation package set into host-specific aspects.
