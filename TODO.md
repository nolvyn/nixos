# Deferred Work

These items were intentionally deferred after the repository audit. They are
not authorization to make changes automatically; review each item before
implementation.

1. **Installer, Disko, impermanence, and recovery safety**
   - Test the fresh-install SSH/age identity bootstrap in a disposable VM.
   - Design SSH server authentication for the pre-kexec and post-kexec stages.
   - Exercise the installer's fingerprint and destructive disk confirmation checks in a disposable VM.
   - Test the Btrfs rollback path in a disposable VM, including nested subvolumes and failure recovery.
   - Decide whether old roots should be retained for 30 days after archival. The current cleanup uses
     the live subvolume's existing mtime, so after more than 30 days of uninterrupted uptime the
     recovery snapshot made at the next reboot can be deleted immediately. Persisted data is not
     affected, but the just-created recovery copy of ephemeral state is lost.
   - Do not change or exercise these paths on either real machine without a reviewed recovery plan.

2. **Syncthing private host-key sharing**
   - Reconsider synchronizing both machines' plaintext SSH/age host-key backups between both peers.
   - Evaluate an offline or separately encrypted recovery backup.

3. **Syncthing database persistence**
   - Decide whether avoiding a full index rescan after ephemeral-root reboots is worth persisting the database.
   - Keep the declaratively managed configuration and secret-provided identity separate from the rebuildable index.

4. **SDDM service ordering**
   - The current `mkForce` ordering was added for a previously observed problem; keep it until that
     behavior can be reproduced safely.
   - When investigating, compare the effective unit with the upstream `systemd-logind` and Plymouth
     ordering and test repeated cold boots before changing it.

5. **Pin mutable AI and MCP tools**
   - Pin the versions used by `npx`, `uvx`, and mutable GitHub invocations.
   - Preserve a deliberate update process for security fixes.

6. **Swap, Zram, and hibernation**
   - Evaluate memory pressure and RAM capacity on both machines.
   - Consider Zram independently from disk-backed swap and hibernation.
   - Do not add hibernation until its interaction with encryption and the current kernel-security settings is designed.

7. **Gaming-specific laptop configuration**
   - Revisit Steam keybindings, workspace rules, and packages if a future laptop is intended for gaming.
   - The currently shared rules are harmless on MoeNote and do not require immediate changes.

8. **Core-dump retention**
   - Decide whether persisted crash dumps should have stricter size or age limits, or be disabled.
   - Balance debugging value against disk usage and the possibility of retaining sensitive process memory.

9. **AppArmor runtime verification**
   - Verify which packaged profiles are actually attached to running applications on both hosts.
   - Add or change profiles individually only when a concrete confinement goal is identified.

10. **Archival Den snapshot provenance**
    - The snapshots under `docs/den/` have an unknown originating revision and intentionally remain
      non-authoritative.
    - If they are regenerated, record the Den revision, source-tree dirty state, generation command,
      and timestamp. Continue using `flake.lock` as the API source of truth.

11. **Build-artifact growth under `projects/`**
    - Rust and Flutter build output reached roughly 389 GB across two repositories before a manual
      cleanup on 2026-07-30. Nothing bounds it today, so it will accumulate again.
    - Research a durable approach before committing: a shared `CARGO_TARGET_DIR`, `sccache`, and
      `cargo-sweep` on a timer address different parts of the problem and are not interchangeable.
    - The two repositories have different causes. One accumulated duplicate dependency trees across
      many target directories; the other accumulated incremental artifacts in a single one. Dev-profile
      debuginfo settings are likely relevant to the second.
    - A shared target directory introduces cargo lock contention between concurrent builds and makes
      `cargo clean` all-or-nothing across projects. Evaluate that cost before adopting it.

12. **Persistent-store visibility and orphan handling**
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

## Intentional decisions

- Install targets are expected to use NVMe storage, so Disko intentionally retains
  `/dev/nvme0n1`; the installer requires an explicit inspection and erase confirmation instead.
- `nixos-anywhere` intentionally remains unpinned to avoid a manual update workflow. The installer
  therefore trusts its upstream GitHub default branch at execution time.
- The 512 MiB ESP and `boot.loader.systemd-boot.configurationLimit = 50` remain unchanged because
  observed use has been acceptable; the limit bounds boot entries only, not store contents. Revisit
  only if `/boot` usage begins growing materially or an installation fails.
- Generation retention was tightened on 2026-07-30 from `--keep 25 --keep-since 30d` to
  `--keep 10 --keep-since 20d` after the store reached 161 GB across 42 generations. Roughly three
  weeks of rollback history is intended; widen it again if a rollback older than that is ever needed.
- Broad AI-agent shell and repository permissions are intentional. Mutable AI/MCP dependencies remain
  deferred above, but the permissions themselves should not be narrowed without a separate decision.
- The packages in `common` are intentionally shared by both machines; closure size alone is not a reason
  to split them into host-specific aspects.
