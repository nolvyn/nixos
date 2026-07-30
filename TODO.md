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

## Intentional decisions

- Install targets are expected to use NVMe storage, so Disko intentionally retains
  `/dev/nvme0n1`; the installer requires an explicit inspection and erase confirmation instead.
- `nixos-anywhere` intentionally remains unpinned to avoid a manual update workflow. The installer
  therefore trusts its upstream GitHub default branch at execution time.
- The 512 MiB ESP and current generation-retention settings remain unchanged because observed use
  has been acceptable. Revisit only if `/boot` usage begins growing materially or an installation fails.
- Broad AI-agent shell and repository permissions are intentional. Mutable AI/MCP dependencies remain
  deferred above, but the permissions themselves should not be narrowed without a separate decision.
- The packages in `common` are intentionally shared by both machines; closure size alone is not a reason
  to split them into host-specific aspects.
