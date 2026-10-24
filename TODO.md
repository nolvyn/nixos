# Deferred Work

Keep only pending work, deferred decisions, and brief constraints needed to resume
safely. Remove completed items; Git history records past work. These items do not
authorize implementation automatically.

1. **Installer and recovery validation**
   - In a disposable VM, test SSH/age identity bootstrap, the full pre-/post-kexec
     installation and first login, fingerprint/erase confirmations, and rollback
     failure recovery, low-space behavior, and boot integration.
   - Do not exercise these paths on either real machine without a reviewed recovery plan.

2. **Cross-host synchronization**
   - Decide which folders to share between WeebMachine and Astraeus, then choose
     a tool and its index/database persistence policy.
   - Keep configuration and secret-provided identities separate from rebuildable
     indexes; exclude recovery credentials unless separately encrypted.

3. **SDDM service ordering**
   - Keep the current `mkForce` ordering until the original problem can be reproduced.
     Compare upstream logind/Plymouth ordering and test repeated cold boots before changing it.

4. **Pin mutable AI and MCP tools**
   - Pin `npx`, `uvx`, OpenCode plugins, and the GitHub flake invocation in `.mcp.json`,
     with a deliberate update process. The installer is intentionally exempt below.

5. **Memory and hibernation decisions**
   - Assess Astraeus memory pressure during native maintenance; consider disk-backed
     swap only if sustained workloads need it.
   - Design encryption/kernel-security compatibility before adding hibernation.

7. **Broader AppArmor confinement — on hold**
   - Resume only by explicit request, application by application, with compatibility
     and denial tests. Do not bulk-load permissive desktop profiles.

8. **Build-artifact growth under `projects/`**
   - Choose a per-project strategy for duplicate target trees and incremental output;
     separate workspaces/FFI integrations are not automatically accidental duplicates.
   - Preserve full debug information for workspace code and incremental compilation.
     Optional dependency-only `[profile.dev.package."*"] debug = 1` trials must account
     for reduced dependency debugging; avoid global overrides.
   - Check Flutter/FFI, editor, debugger, and executable paths before relocating caches.
     Shared target directories introduce lock contention and shared `cargo clean` scope.
   - Cargo global-cache cleanup does not cover build artifacts. Do not add unmaintained
     `cargo-sweep` to a timer; `sccache` has incremental/linker limitations here.

9. **Persistent-store growth and orphan handling**
   - Gather several monthly reports after deployment before choosing any deletion policy.
     Track both undeclared leftovers and growth in declared directories such as `projects/`.
   - An absent mount or old timestamp does not prove data is disposable. Preserve
     personal/tool state, datasets, and VM images; exclude symlinks/protected paths
     and account for unreadable metadata.
   - Any future orphan cleanup must reject incomplete-mount or implausible mass-orphan
     states. Consider quarantine/restore before deletion; mixed precious/bulk storage
     separation remains a separate migration decision.

10. **Astraeus follow-up**
    - Retire the mac-app-util Tahoe source pin/SBCL wrapper only after an equivalent
      upstream fix is verified on the Mac; retain the validated OmniWM 0.7.6 pin.
    - Retire the guarded MAS patches when upstream filters diagnostic output from
      numeric app IDs and supplies mas 7's root credentials plus configured-user context.
    - Decide separately whether to pin mutable Homebrew taps/casks and Web Store payloads.
    - Review old `ipc.sock`/`ipc.sock.secret` in `~/Library/Caches/com.barut.OmniWM`
      only when cleanup is requested; never touch the live Application Support socket.
    - Review any remaining temporary Terminal browser App Data grants in System Settings;
      do not grant extra access merely to inspect protected browser directories.

11. **Checks after a normal deployment**
    - Verify Zram, the monthly storage timer, private report history, and one-time Fish summary.
    - Verify coredump limits/retention; processing may temporarily exceed the aggregate limit.
    - Verify ping/Avahi AppArmor attachment on WeebMachine and printer queue persistence,
      rollback, and a physical test print. Broader confinement remains on hold above.
    - Verify GitHub CLI account selection/keyring login survives rollback and Quickshell
      renders normally in a fresh session.
    - Run native Darwin build checks on Astraeus. Evaluation/VM tests do not establish
      native build, hardware, or real-user runtime behavior.

12. **Share VS Code/Cursor defaults — deferred**
    - Extract identical settings/common extensions into `lib/editor-common.nix`,
      preserving each editor's additions and package selections.

13. **Share MCP server definitions — deferred**
    - Extract repeated commands/arguments into `lib/mcp-servers.nix`; preserve each
      agent's server selection and format. Keep helpers outside auto-discovered `modules/`.

14. **Reduce repeated declarations — deferred**
    - Reuse one overlay list in `modules/setup.nix`, preserving its order.
    - Share a font-package function in `fonts.nix`, using each platform's own `pkgs`.
    - Generate Hyprland's existing out-of-store links from an explicit path list.
    - Preserve evaluated configuration when making these refactors.

## Intentional decisions

- Keep the NVMe Disko target, 512 MiB ESP, and 50 boot-entry limit unless hardware
  or `/boot` capacity warrants review; installation requires inspection/erase confirmation.
- Keep `nixos-anywhere` unpinned. Its local SSH override must fail on upstream drift
  rather than silently dropping host authentication.
- Generation retention (`--keep 10 --keep-since 20d`) intentionally provides roughly
  three weeks of rollback history; widen it only if older recovery becomes necessary.
- Broad AI-agent permissions and shared workstation packages are deliberate;
  changing those policies requires a separate decision.
