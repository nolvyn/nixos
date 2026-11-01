# Pending Work

Only pending work and deferred decisions belong here. Entries do not authorize
implementation or deployment automatically.

## Recovery and deployment qualification

- Verify rescue media, private LUKS unlock access, previous-generation boot and
  journal-aware recovery/handoff procedures.
- Qualify installer SSH/age bootstrap, full pre-/post-kexec installation, first
  login and fingerprint/erase confirmations in a disposable VM.
- Validate SDDM through three physical cold boots with the actual displays;
  check intended-session input for two minutes and logout/login on each.
- Establish monthly storage-report history and verify the once-per-report Fish
  notification. Check printer queues and GitHub CLI/keyring state survive rollback.
- Perform a physical print and check Quickshell in a fresh session.

## Optional confinement

- Decide separately on Celluloid confinement and physical playback,
  GPU/audio/portal qualification; keep the candidate disabled meanwhile.
- Decide separately on qBittorrent enforcement: verify profile loading/process
  label after closing/reopening, real transfers, TLS and VPN behavior. Preserve
  state, `~/torrents` scope and disabled Search.
- Decide whether to resume LocalSend sender/discovery tests, Anki WebEngine
  compatibility without weakening its native sandbox, and ONLYOFFICE attachment
  redesign. Assess further applications individually; no bulk permissive profiles.
- Defer CUPS attachment until its actual driver/filter chain and queues qualify.

## Deferred choices

- Cross-host folder synchronization: choose folders/tool and index persistence;
  separate identity from rebuildable indexes and encrypt any recovery credentials.
- Pin mutable `npx`, `uvx`, OpenCode plugins and the `.mcp.json` GitHub invocation
  with an update process; retain the installer exemption.
- Share VS Code/Cursor defaults while preserving editor-specific additions.
- Gather several monthly persistence reports before choosing cleanup policy.
  Preserve precious state and bulk data; reject incomplete/missing-mount or
  implausible mass-orphan scans, exclude symlinks/protected paths, and consider
  quarantine/restore before deletion. Storage separation is a separate migration.

## Astraeus follow-up

- Run native Darwin builds and real-user/hardware checks; evaluation is insufficient.
- Retire the mac-app-util Tahoe pin/SBCL wrapper and MAS guards only after matching
  upstream fixes work on the Mac; retain the OmniWM pin.
- Decide whether to pin Homebrew taps/casks and Web Store payloads.
- Inspect old OmniWM `ipc.sock`/`ipc.sock.secret` cache files only when cleanup is
  requested; preserve the live Application Support socket.
- Review optional browser App Data access without granting it merely to inspect
  protected profile directories.
