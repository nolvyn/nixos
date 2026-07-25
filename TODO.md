# Deferred Work

These items were intentionally deferred after the repository audit. They are
not authorization to make changes automatically; review each item before
implementation.

1. **Installer, Disko, impermanence, and recovery safety**
   - Test the fresh-install SSH/age identity bootstrap in a disposable VM.
   - Add explicit target-machine and disk-identity confirmation to the installer.
   - Design SSH server authentication for the pre-kexec and post-kexec stages.
   - Pin `nixos-anywhere` instead of executing its mutable default branch.
   - Reproduce the possible nested-Btrfs rollback edge case in a disposable VM.
   - Do not change or exercise these paths on either real machine without a reviewed recovery plan.

2. **Syncthing private host-key sharing**
   - Reconsider synchronizing both machines' plaintext SSH/age host-key backups between both peers.
   - Evaluate an offline or separately encrypted recovery backup.

3. **Syncthing database persistence**
   - Decide whether avoiding a full index rescan after ephemeral-root reboots is worth persisting the database.
   - Keep the declaratively managed configuration and secret-provided identity separate from the rebuildable index.

4. **AppArmor application profiles**
   - Decide which applications or services would benefit from confinement.
   - Add and test profiles individually; do not enable a large unreviewed profile set.

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
