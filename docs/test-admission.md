# Shared test admission

`scripts/host-test-admission.py` is the version 2.5 Linux admission artifact;
its shared registry/API protocol remains version 2. Its
source is included in the `weeb-test-admission` package provided by the development
aspect. Consumers pin the installed module's exact path and SHA-256 before
executing it. Version 2 does not claim compatibility with missing version 1 bytes.

## Installation and persistence

Run `weeb-test-admission --install` to create a private, user-owned copy under
`~/.local/share/weeb-test-admission-v2.5-<digest-prefix>/host_admission.py`. The
installer prints the complete digest and path. It accepts an explicit absolute
content-addressed directory for installing into the corresponding persistent
backing directory before a system activation. Existing differing files are
refused and retained. The final module is a regular file with mode 0600;
consumers using `O_NOFOLLOW` must not import a Home Manager or Nix-store symlink.

The development aspect persists the current digest's directory. Older installed
versions are not deleted. The registry itself remains transient host coordination
state under `/tmp/weeb-test-admission-<host-uid>`; it is not a cache or a source archive.

`weeb-test-admission --initialize-registry` performs normal empty-registry
bootstrap without acquiring a lease. Consumers that inspect `state.json` before
admission must initialize it first (`Registry().initialize()`). Initialization is
idempotent and never resets existing state. Every consumer must use the same
registry; a private registry is suitable only for disposable validation fixtures.

## Admission contract

`Registry.admit(project, memory, disk, memory_floor, disk_floor, claims, ports,
owner_scope)` returns a lease with `token`, `receipt`, `closed`, `check()` and
`release(identities, cleanup_verified)`. Budgets and floors are integer bytes.
Claims are canonical absolute paths and overlap includes ancestor/descendant
paths. All outstanding memory and disk reservations plus the maximum host floor
must remain available. Disk checks conservatively charge the complete reservation
against the registry and every claimed filesystem, including Btrfs subvolumes.
Checks intentionally retain this conservative headroom as workloads consume space.

Scope prefixes and the default registry name use a verified host user-manager UID.
The helper accepts the initial identity UID map or the exact single UID-0 map
created by `unshare --user --map-root-user`. It checks that mapping against the
current kernel user-manager cgroup and private `/run/user/<host-uid>` ownership.
File ownership checks continue to use the current namespace UID. Environment
variables cannot select the host UID. Ambiguous or mismatched mapping shapes
fail closed; a nested namespace with the same verified mapping is not rejected
merely because it is nested. Existing immutable artifact copies are not rewritten.

The owner must run in a dedicated UUID-named user-systemd scope with
`Delegate=no` and `KillMode=control-group`. Its receipt binds the exact unit,
unified cgroup path, full controller identity and up to two live ancestor
supervisors. `identity(pid=None)` returns PID, canonical decimal-string start
time, boot ID and the observer's PID namespace. This namespace identifies the
address space of the numeric PID and remains available for unreaped zombies.

Scope observations use bounded recursive kernel inventories and four paired,
fresh census attempts. Unresolved attempts request a 5 ms pause before the next
fresh pair, up to three pauses; scheduling may delay wakeups. Stable first-pair
success and observed reuse, escape or denial receive no added retries.
A confirmed disappearance during an omission check requests another complete
pair within the same attempt bound. `CensusProcessGone` is an `AdmissionError`;
direct callers must not treat it as terminal or cleanup success.
Missing identities, PID reuse, scope escape, permission
failures and incomplete observations cannot establish successful cleanup. Release
independently requires the original live controller and no remaining workers;
the caller's Boolean and historical identity list are insufficient by themselves.
The helper never signals, reaps or deletes project resources.

## Failure handling and validation

The private registry uses a bounded exclusive lock, directory-relative file
operations and atomic state replacement. A durable pending marker precedes each
write; the completed marker binds the committed state's SHA-256. A crash during
mutation, mismatched digest, malformed state or foreign boot/namespace blocks
further admission. A live controller or populated orphan scope retains its claims, ports and
resource charge. Ended-controller reservations whose exact kernel scope is
absent or recursively empty retire automatically during admission and lease
checks. Fresh paired observations and a final recheck retain populated scopes and
reject denied reads, foreign identity domains and incomplete observations. PID
reuse in the same verified domain proves the original controller ended; its
replacement is never signaled or treated as an owned worker. Before the normal locked transaction removes
any row, its complete evidence is durably archived in a fresh private
`retired-<token>-<nonce>.json` file. An interrupted archive never replaces prior
evidence or changes the original row. Retirement is accounting only, explicitly
`cleanupVerified: false`; it signals no process and deletes no claimed data.
This avoids historical bookkeeping vetoes without disabling live-job protection.
Legacy manual-recovery tooling is separate from this normal accounting path. A write failure poisons the current registry object and
attempts durable pending-marker invalidation. If that invalidation also fails,
the operation reports an uncertain outcome: stop consumers and preserve evidence
for review. Do not infer that a failed filesystem operation left state unchanged.
Preserve registry evidence for independent recovery
review; do not remove state or use a different registry to bypass a refusal.

Port checks observe IPv4/IPv6 TCP/UDP occupancy in addition to cooperative port
reservations. This is admission coordination, not kernel resource confinement or
protection against later unmanaged allocation. Existing per-run resource limits,
process ownership, storage accounting and cleanup guards remain necessary.

Run `python3 scripts/test-host-test-admission.py` for disposable concurrency,
crash, identity, resource, installation and cleanup tests. Local socket tests
require a socket-capable execution environment. Real user-systemd scope smoke
validation additionally checks the kernel scope and unit-property integration.
