#!/usr/bin/env python3
"""Version 2 cooperative Linux test admission; no process signaling or recovery overrides.

All consumers must share the default registry. Reservations are conservative, not
kernel resource limits. Ended reservations retire automatically with retained evidence.
"""

import contextlib
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import socket
import stat
import subprocess
import tempfile
import time

VERSION = 2  # Shared registry/API protocol remains compatible.
ARTIFACT_VERSION = "2.5"
GiB = 1024**3
MAX_RECORD = 1024 * 1024
MAX_MEMBERS = 4096


class AdmissionError(RuntimeError):
    pass


class CensusProcessGone(AdmissionError):
    """Confirmed disappearance requests fresh observations, never success."""

    def __init__(self, pid):
        self.pid = pid
        super().__init__(f"process disappeared while checking census omission: {pid}")


def _read(path, limit=65536):
    with Path(path).open("rb") as stream:
        value = stream.read(limit + 1)
    if len(value) > limit:
        raise AdmissionError("observation exceeds bound")
    return value.decode("ascii")


def _stat(pid):
    data = _read(f"/proc/{pid}/stat")
    fields = data.rsplit(")", 1)[1].split()
    start = fields[19]
    if not re.fullmatch(r"[1-9][0-9]{0,19}", start) or int(start) >= 2**64:
        raise AdmissionError("invalid process start identity")
    return start, fields[0]


def identity(pid=None):
    """PID/start/boot plus observer PID namespace; includes unreaped zombies.

    The namespace identifies the address space of the numeric PID, not the
    target's innermost namespace (which disappears for terminal processes).
    """
    pid = os.getpid() if pid is None else pid
    if type(pid) is not int or pid <= 0:
        raise AdmissionError("invalid PID")
    try:
        before, _ = _stat(pid)
        boot = _read("/proc/sys/kernel/random/boot_id").strip()
        pidns = os.readlink("/proc/self/ns/pid")
        after, _ = _stat(pid)
    except (FileNotFoundError, ProcessLookupError):
        # An exited zombie can retain stat but lose its namespace handle.
        # Such ambiguity is not a proven disappearance.
        try:
            Path(f"/proc/{pid}").lstat()
        except FileNotFoundError:
            return None
        raise AdmissionError("process identity unavailable for existing PID")
    if before != after or pidns != os.readlink("/proc/self/ns/pid"):
        raise AdmissionError("process identity changed during observation")
    result = dict(pid=pid, start=before, boot=boot, pidns=pidns)
    _validate_identity(result)
    return result


def _validate_identity(row):
    if (
        not isinstance(row, dict)
        or set(row) != {"pid", "start", "boot", "pidns"}
        or type(row["pid"]) is not int
        or row["pid"] <= 0
        or not isinstance(row["start"], str)
        or not re.fullmatch(r"[1-9][0-9]{0,19}", row["start"])
        or int(row["start"]) >= 2**64
        or not isinstance(row["boot"], str)
        or not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", row["boot"])
        or not isinstance(row["pidns"], str)
        or not re.fullmatch(r"pid:\[[0-9]+\]", row["pidns"])
    ):
        raise AdmissionError("malformed full process identity")


def _pid_scope(pid):
    rows = _read(f"/proc/{pid}/cgroup").splitlines()
    if len(rows) != 1 or not rows[0].startswith("0::/"):
        raise AdmissionError("exact unified process cgroup required")
    return rows[0][3:]


def _within(path, scope):
    return path == scope["path"] or path.startswith(scope["path"] + "/")


def _omitted_identity_retryable(pid, expected, scope):
    """Only an unchanged terminal identity is retryable; disappearance is typed."""
    if expected is None:
        raise AdmissionError("process identity changed after census omission")
    current = identity(pid)
    if current is None:
        raise CensusProcessGone(pid)
    if current != expected:
        raise AdmissionError("process identity changed after census omission")
    try:
        path = _pid_scope(pid)
        if not _within(path, scope):
            return False
        start, state = _stat(pid)
    except (FileNotFoundError, ProcessLookupError):
        # Missing proc metadata is not itself proof of exit. identity checks
        # that the numeric proc directory is actually absent; ambiguity raises.
        current = identity(pid)
        if current is None:
            raise CensusProcessGone(pid)
        raise AdmissionError("process metadata changed after census omission")
    if start != expected["start"]:
        raise AdmissionError("process identity changed after census omission")
    current = identity(pid)
    if current is None:
        raise CensusProcessGone(pid)
    if current != expected:
        raise AdmissionError("process identity changed after census omission")
    return _within(path, scope) and state in {"Z", "X", "x"}


def _host_uid():
    """Verify the host user-manager UID across a single map-root-user namespace.

    File ownership is still checked against the caller's namespace UID. Only
    scope names and the shared registry use this separately verified host UID.
    Other mapping shapes are unsupported and fail closed; the kernel cgroup
    and private host runtime ownership also bind the mapped UID.
    """
    uid = os.getuid()
    if os.geteuid() != uid:
        raise AdmissionError("real/effective UID mismatch")
    mapping = _read("/proc/self/uid_map")
    lines = [line.split() for line in mapping.splitlines()]
    if (
        len(lines) != 1
        or len(lines[0]) != 3
        or any(not re.fullmatch(r"0|[1-9][0-9]{0,9}", field) for field in lines[0])
    ):
        raise AdmissionError("unsupported or ambiguous user namespace mapping")
    inside, outside, count = map(int, lines[0])
    if (inside, outside, count) == (0, 0, 2**32 - 1):
        host_uid = uid
    elif inside == 0 and count == 1 and uid == 0 and 0 < outside < 2**32 - 1:
        host_uid = outside
    else:
        raise AdmissionError("unsupported user namespace mapping")
    current = _pid_scope(os.getpid())
    prefix = f"/user.slice/user-{host_uid}.slice/user@{host_uid}.service/"
    if not current.startswith(prefix):
        raise AdmissionError("UID mapping does not match current user-manager cgroup")
    runtime = Path(f"/run/user/{host_uid}")
    meta = runtime.lstat()
    if (
        not stat.S_ISDIR(meta.st_mode)
        or stat.S_IMODE(meta.st_mode) != 0o700
        or meta.st_uid != uid
        or runtime.resolve(strict=True) != runtime
    ):
        raise AdmissionError("private mapped host runtime directory required")
    if (
        _read("/proc/self/uid_map") != mapping
        or os.getuid() != uid
        or os.geteuid() != uid
    ):
        raise AdmissionError("user namespace identity changed during observation")
    return host_uid


def _validate_scope(scope):
    if not isinstance(scope, dict) or set(scope) != {"unit", "path", "supervisors"}:
        raise AdmissionError("exact owner scope required")
    unit, path = scope["unit"], scope["path"]
    host_uid = _host_uid()
    prefix = f"/user.slice/user-{host_uid}.slice/user@{host_uid}.service/"
    if (
        not isinstance(unit, str)
        or not re.fullmatch(r"[a-z][a-z0-9-]{0,100}-[a-f0-9]{32}\.scope", unit)
        or len(unit) > 200
        or not isinstance(path, str)
        or not path.startswith(prefix)
        or PurePosixPath(path).name != unit
        or str(PurePosixPath(path)) != path
        or ".." in PurePosixPath(path).parts
    ):
        raise AdmissionError("exact owned user scope required")
    if not isinstance(scope["supervisors"], list) or len(scope["supervisors"]) > 2:
        raise AdmissionError("bounded supervisor list required")
    for row in scope["supervisors"]:
        _validate_identity(row)
    if len({row["pid"] for row in scope["supervisors"]}) != len(scope["supervisors"]):
        raise AdmissionError("duplicate supervisor")


def _scope_properties(unit):
    if not isinstance(unit, str) or not re.fullmatch(
        r"[a-z][a-z0-9-]{0,100}-[a-f0-9]{32}\.scope", unit
    ):
        raise AdmissionError("dedicated UUID scope required")
    names = {"Id", "ControlGroup", "Delegate", "KillMode", "LoadState", "ActiveState"}
    result = subprocess.run(
        [
            "systemctl",
            "--user",
            "show",
            unit,
            "--no-pager",
            "--property=" + ",".join(sorted(names)),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=3,
    )
    if len(result.stdout) > 8192:
        raise AdmissionError("scope unit observation exceeds bound")
    rows = result.stdout.decode("ascii").splitlines()
    values = _unique_object(row.split("=", 1) for row in rows)
    if set(values) != names or values["Id"] != unit:
        raise AdmissionError("incomplete exact scope properties")
    return values


def _verify_unit(scope):
    _validate_scope(scope)
    if _scope_properties(scope["unit"]) != dict(
        Id=scope["unit"],
        ControlGroup=scope["path"],
        Delegate="no",
        KillMode="control-group",
        LoadState="loaded",
        ActiveState="active",
    ):
        raise AdmissionError("scope unit binding or cleanup policy changed")


def _verify_supervisors(row):
    expected = row["owner_scope"]["supervisors"]
    if not expected:
        return
    controller = row["controller"]
    parents = set()
    pid = controller["pid"]
    for _ in range(64):
        fields = _read(f"/proc/{pid}/stat").rsplit(")", 1)[1].split()
        pid = int(fields[1])
        if pid <= 1 or pid in parents:
            break
        parents.add(pid)
    for supervisor in expected:
        if (
            supervisor["pid"] not in parents
            or supervisor["boot"] != controller["boot"]
            or supervisor["pidns"] != controller["pidns"]
            or identity(supervisor["pid"]) != supervisor
        ):
            raise AdmissionError("only exact live ancestor supervisors may be excluded")


def _scope_census(scope):
    _validate_scope(scope)
    root = Path("/sys/fs/cgroup" + scope["path"])
    if root.resolve() != root:
        raise AdmissionError("redirected scope refused")
    pending, seen, members = [root], set(), set()
    while pending:
        path = pending.pop()
        meta = path.lstat()
        if not stat.S_ISDIR(meta.st_mode) or path in seen or len(seen) >= 256:
            raise AdmissionError("invalid or excessive cgroup inventory")
        seen.add(path)
        for item in _read(path / "cgroup.procs").split():
            if not re.fullmatch(r"[1-9][0-9]*", item):
                raise AdmissionError("malformed cgroup PID")
            members.add(int(item))
            if len(members) > MAX_MEMBERS:
                raise AdmissionError("scope member bound exceeded")
        for child in path.iterdir():
            kind = child.lstat().st_mode
            if stat.S_ISLNK(kind):
                raise AdmissionError("redirected cgroup child refused")
            if stat.S_ISDIR(kind):
                pending.append(child)
    events = _read(root / "cgroup.events").splitlines()
    populated = [row.split()[1] for row in events if row.startswith("populated ")]
    if len(populated) != 1 or populated[0] not in {"0", "1"}:
        raise AdmissionError("complete recursive populated observation required")
    return dict(members=members, populated=populated[0] == "1")


def _verify_live_scope(row):
    """Four paired, fresh censuses; omissions/reuse/escape never imply exit."""
    scope = row["owner_scope"]
    controller = row["controller"]
    for attempt in range(4):
        opening = _scope_census(scope)
        before = {pid: identity(pid) for pid in opening["members"]}
        closing = _scope_census(scope)
        after = {pid: identity(pid) for pid in opening["members"] | closing["members"]}
        retry = False
        for pid, old in before.items():
            current = after[pid]
            if current is not None and current != old:
                raise AdmissionError("process identity changed between censuses")
            if pid in closing["members"]:
                retry |= old is None or current is None
            elif current is not None:
                try:
                    terminal = _omitted_identity_retryable(pid, current, scope)
                except CensusProcessGone:
                    retry = True
                else:
                    if not terminal:
                        raise AdmissionError("live process left its owner scope")
        retry |= bool(closing["members"] - opening["members"])
        for expected in [controller, *scope["supervisors"]]:
            pid = expected["pid"]
            if before.get(pid) != expected or after.get(pid) != expected:
                raise AdmissionError("controller or supervisor identity changed")
            if pid not in closing["members"]:
                raise AdmissionError("controller or supervisor left its scope")
        if not retry:
            if not closing["populated"] or not closing["members"]:
                raise AdmissionError("live owner scope is not populated")
            return closing
        if attempt < 3:
            # Keep four fresh pairs; let an unresolved startup burst settle.
            time.sleep(0.005)
    raise AdmissionError("unresolved identity after four complete censuses")


def _number(value):
    if type(value) is not int or value < 0 or value > 2**63 - 1:
        raise AdmissionError("nonnegative bounded integer budget required")
    return value


def _walk_claim(value):
    path = Path(value)
    if (
        not path.is_absolute()
        or str(PurePosixPath(path)) != str(path)
        or ".." in path.parts
    ):
        raise AdmissionError("absolute normalized claim required")
    meta = path.lstat()
    if not stat.S_ISDIR(meta.st_mode) or path.resolve(strict=True) != path:
        raise AdmissionError("unredirected directory path claim required")
    return dict(path=str(path), kind="directory", dev=meta.st_dev, ino=meta.st_ino)


def _claims(values):
    if not isinstance(values, (list, tuple)) or not 1 <= len(values) <= 128:
        raise AdmissionError("bounded path claims required")
    paths = set()
    for value in values:
        path = Path(value)
        if not path.is_absolute():
            raise AdmissionError("absolute path claim required")
        paths.add(str(path.resolve()))
    return sorted(paths)


def _overlap(left, right):
    return (
        left == right
        or left == "/"
        or right == "/"
        or left.startswith(right + "/")
        or right.startswith(left + "/")
    )


def _memory_available():
    rows = _read("/proc/meminfo").splitlines()
    values = [row.split()[1:] for row in rows if row.startswith("MemAvailable:")]
    if len(values) != 1 or len(values[0]) != 2 or values[0][1] != "kB":
        raise AdmissionError("MemAvailable unavailable")
    return int(values[0][0]) * 1024


def _disk_available(path):
    row = os.statvfs(path)
    return row.f_bavail * row.f_frsize


def _check_disk(rows, registry_root):
    # Btrfs subvolumes can have different st_dev on the same pool. Reserve the
    # complete sum against every claimed filesystem instead of guessing aliases.
    required = sum(row["disk"] for row in rows) + max(row["disk_floor"] for row in rows)
    anchors = {Path(registry_root)}
    for row in rows:
        for claim in row["claims"]:
            path = Path(claim)
            while True:
                try:
                    path.stat()
                    break
                except FileNotFoundError:
                    path = path.parent
            if path.resolve() != path:
                raise AdmissionError("claimed path was redirected")
            anchors.add(path)
    for path in anchors:
        if _disk_available(path) < required:
            raise AdmissionError("disk reservation and host floor unavailable")


def _ports_available(ports):
    # Cooperative reservations supplement this best-effort kernel observation.
    # Do not retain listening sockets or change any external process.
    with contextlib.ExitStack() as stack:
        for port in ports:
            for family, address in [
                (socket.AF_INET, "0.0.0.0"),
                (socket.AF_INET6, "::"),
            ]:
                for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                    sock = stack.enter_context(socket.socket(family, kind))
                    if family == socket.AF_INET6:
                        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                    try:
                        sock.bind((address, port))
                    except OSError as error:
                        raise AdmissionError(f"port {port} unavailable") from error


def _reservation_ended(row):
    """Accounting-only retirement, not a historical cleanup certificate.

    Keep live scopes charged even after their controller ends. Never interpret
    denied or partial kernel observations as an empty scope.
    """
    controller = row["controller"]
    def original_live():
        current = identity(controller["pid"])
        if current is not None and any(current[key] != controller[key] for key in ("boot", "pidns")):
            raise AdmissionError("reservation controller observation has foreign identity domain")
        return current == controller

    if original_live():
        return False
    scope = row["owner_scope"]
    root = Path("/sys/fs/cgroup" + scope["path"])
    for _ in range(2):
        try:
            census = _scope_census(scope)
        except FileNotFoundError as error:
            # A missing child or cgroup.procs is not proof the root is absent.
            try:
                root.lstat()
            except FileNotFoundError:
                census = dict(members=set(), populated=False)
            else:
                raise AdmissionError("incomplete abandoned scope observation") from error
        if census["members"] or census["populated"]:
            return False
        if original_live():
            raise AdmissionError("original reservation controller became live; retained")
    return True


class Registry:
    def __init__(self, root=None):
        self.root = Path(
            root if root is not None else f"/tmp/weeb-test-admission-{_host_uid()}"
        )
        if not self.root.is_absolute():
            raise AdmissionError("absolute registry path required")
        self.root.mkdir(mode=0o700, exist_ok=True)
        meta = self.root.lstat()
        if (
            not stat.S_ISDIR(meta.st_mode)
            or meta.st_uid != os.getuid()
            or stat.S_IMODE(meta.st_mode) != 0o700
            or self.root.resolve() != self.root
        ):
            raise AdmissionError("private unredirected registry required")
        self._inode = (meta.st_dev, meta.st_ino)
        self._held_locks = {}
        self._poisoned = False

    @contextlib.contextmanager
    def _locked(self):
        if self._poisoned:
            raise AdmissionError(
                "pending or uncertain registry transaction; retain for review"
            )
        dfd = os.open(
            self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
        )
        try:
            meta = os.fstat(dfd)
            if (
                (meta.st_dev, meta.st_ino) != self._inode
                or meta.st_uid != os.getuid()
                or stat.S_IMODE(meta.st_mode) != 0o700
            ):
                raise AdmissionError("registry directory identity changed")
            fd = os.open(
                "lock",
                os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
                dir_fd=dfd,
            )
            try:
                self._private(fd)
                deadline = time.monotonic() + 3
                while True:
                    try:
                        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                        break
                    except BlockingIOError:
                        if time.monotonic() >= deadline:
                            raise AdmissionError("registry lock deadline exceeded")
                        time.sleep(0.01)
                named = os.stat("lock", dir_fd=dfd, follow_symlinks=False)
                held = os.fstat(fd)
                if (named.st_dev, named.st_ino) != (held.st_dev, held.st_ino):
                    raise AdmissionError("registry lock identity changed")
                self._held_locks[dfd] = (held.st_dev, held.st_ino)
                try:
                    yield dfd
                finally:
                    self._held_locks.pop(dfd, None)
            finally:
                os.close(fd)
        finally:
            os.close(dfd)

    @staticmethod
    def _private(fd):
        meta = os.fstat(fd)
        if (
            not stat.S_ISREG(meta.st_mode)
            or meta.st_uid != os.getuid()
            or meta.st_nlink != 1
            or stat.S_IMODE(meta.st_mode) != 0o600
            or meta.st_size > MAX_RECORD
        ):
            raise AdmissionError("private bounded registry file required")

    def _load(self, dfd):
        try:
            fd = os.open(
                "state.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=dfd
            )
        except FileNotFoundError:
            # A lock without state can be a crash before first admission; no lease
            # was published. Never replace malformed or unfamiliar existing state.
            lock = self._open_held_lock(dfd, os.O_RDONLY)
            try:
                if os.read(lock, 128):
                    raise AdmissionError(
                        "committed registry state missing; retain for review"
                    )
            finally:
                os.close(lock)
            host = identity()
            return dict(
                version=VERSION, boot=host["boot"], pidns=host["pidns"], runs={}
            )
        with os.fdopen(fd, "rb") as stream:
            self._private(stream.fileno())
            payload = stream.read(MAX_RECORD + 1)
            if len(payload) > MAX_RECORD:
                raise AdmissionError("registry grew beyond bound")
            lock = self._open_held_lock(dfd, os.O_RDONLY)
            try:
                marker = os.read(lock, 129)
            finally:
                os.close(lock)
            expected = (
                b"v2-committed " + hashlib.sha256(payload).hexdigest().encode() + b"\n"
            )
            if marker != expected:
                raise AdmissionError(
                    "pending or mismatched registry transaction; retain for review"
                )
            value = json.loads(
                payload,
                object_pairs_hook=_unique_object,
                parse_constant=lambda value: _invalid_constant(),
            )
        if (
            not isinstance(value, dict)
            or set(value) != {"version", "boot", "pidns", "runs"}
            or value["version"] != VERSION
            or not isinstance(value["runs"], dict)
            or len(value["runs"]) > 256
        ):
            raise AdmissionError("unrecognized registry state; retain for review")
        host = identity()
        if value["boot"] != host["boot"] or value["pidns"] != host["pidns"]:
            raise AdmissionError("foreign boot or PID namespace registry retained")
        for token, row in value["runs"].items():
            if not isinstance(token, str) or not re.fullmatch("[a-f0-9]{32}", token):
                raise AdmissionError("invalid lease token")
            _validate_row(token, row)
            if any(row["controller"][key] != value[key] for key in ("boot", "pidns")):
                raise AdmissionError("foreign controller identity domain retained")
        return value

    def _write(self, dfd, value):
        try:
            self._write_transaction(dfd, value)
        except BaseException as error:
            self._poisoned = True
            try:
                # Includes failure after flushing the final committed marker:
                # make its visible bytes fail closed before dropping the lock.
                self._mark(dfd, b"v2-pending\n")
            except BaseException as invalidation_error:
                error.add_note(
                    "registry invalidation also failed; outcome uncertain; "
                    "stop consumers and preserve evidence: " + str(invalidation_error)
                )
            raise

    def _write_transaction(self, dfd, value):
        data = (json.dumps(value, sort_keys=True, allow_nan=False) + "\n").encode()
        if len(data) > MAX_RECORD:
            raise AdmissionError("registry record bound exceeded")
        self._mark(dfd, b"v2-pending\n")
        name = ".state-" + secrets.token_hex(16)
        fd = os.open(
            name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=dfd,
        )
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, "state.json", src_dir_fd=dfd, dst_dir_fd=dfd)
            os.fsync(dfd)
            self._mark(
                dfd,
                b"v2-committed " + hashlib.sha256(data).hexdigest().encode() + b"\n",
            )
        finally:
            # Only this invocation's private temporary file, never user evidence.
            try:
                os.unlink(name, dir_fd=dfd)
            except FileNotFoundError:
                pass

    def _open_held_lock(self, dfd, flags):
        fd = os.open("lock", flags | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=dfd)
        try:
            self._private(fd)
            meta = os.fstat(fd)
            if (meta.st_dev, meta.st_ino) != self._held_locks.get(dfd):
                raise AdmissionError("held registry lock identity changed")
            return fd
        except BaseException:
            os.close(fd)
            raise

    def _mark(self, dfd, data):
        fd = self._open_held_lock(dfd, os.O_WRONLY)
        try:
            self._private(fd)
            with os.fdopen(fd, "wb", closefd=False) as stream:
                stream.truncate(0)
                stream.write(data)
                stream.flush()
                os.fsync(fd)
        finally:
            os.close(fd)

    def initialize(self):
        """Normal empty-registry bootstrap; never reset existing state."""
        with self._locked() as dfd:
            state = self._load(dfd)
            try:
                os.stat("state.json", dir_fd=dfd, follow_symlinks=False)
            except FileNotFoundError:
                self._write(dfd, state)

    def _archive_retired(self, dfd, token, row, state):
        """Durable evidence before accounting changes; never touch claimed data.

        Fresh names make a partial archive from an interrupted attempt harmless.
        The original registry row remains authoritative until normal commit.
        """
        evidence = dict(
            policy="ended-scope-accounting-v1", cleanupVerified=False,
            token=token, row=row, version=VERSION,
            boot=state["boot"], pidns=state["pidns"],
        )
        data = (json.dumps(evidence, sort_keys=True, allow_nan=False) + "\n").encode()
        if len(data) > MAX_RECORD:
            raise AdmissionError("retirement evidence exceeds bound")
        name = "retired-" + token + "-" + secrets.token_hex(16) + ".json"
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=dfd)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.fsync(dfd)

    def _retire_ended(self, dfd, state):
        ended = [(token, row) for token, row in state["runs"].items()
                 if _reservation_ended(row)]
        if not ended:
            return
        # Observe every selected scope again before the transaction. Permission
        # failures and newly populated scopes preserve all selected rows.
        if not all(_reservation_ended(row) for _, row in ended):
            raise AdmissionError("reservation activity changed during retirement")
        for token, row in ended:
            self._archive_retired(dfd, token, row, state)
        if not all(_reservation_ended(row) for _, row in ended):
            raise AdmissionError("reservation activity changed before retirement commit")
        for token, _ in ended:
            del state["runs"][token]
        self._write(dfd, state)

    def admit(
        self,
        project,
        memory,
        disk,
        memory_floor,
        disk_floor,
        claims,
        ports=(),
        owner_scope=None,
    ):
        memory, disk, memory_floor, disk_floor = map(
            _number, (memory, disk, memory_floor, disk_floor)
        )
        project = str(Path(project).resolve(strict=True))
        claims = _claims(claims)
        if project not in claims:
            raise AdmissionError("exact project path claim required")
        ports = list(ports)
        if (
            len(ports) > 64
            or len(set(ports)) != len(ports)
            or any(type(p) is not int or not 1 <= p <= 65535 for p in ports)
        ):
            raise AdmissionError("bounded unique ports required")
        scope = copy.deepcopy(owner_scope)
        _verify_unit(scope)
        controller = identity()
        if controller is None or not _within(_pid_scope(controller["pid"]), scope):
            raise AdmissionError("controller must own the admitted scope")
        row = dict(
            project=project,
            memory=memory,
            disk=disk,
            memory_floor=memory_floor,
            disk_floor=disk_floor,
            claims=claims,
            ports=ports,
            controller=controller,
            owner_scope=scope,
            created=time.time(),
        )
        _verify_supervisors(row)
        with self._locked() as dfd:
            state = self._load(dfd)
            self._retire_ended(dfd, state)
            if len(state["runs"]) >= 256:
                raise AdmissionError("lease count bound exceeded")
            _verify_live_scope(row)
            for previous in state["runs"].values():
                # A controllerless but populated scope still owns its claims.
                if identity(previous["controller"]["pid"]) == previous["controller"]:
                    _verify_live_scope(previous)
                if (
                    previous["project"] == project
                    or set(previous["ports"]) & set(ports)
                    or any(_overlap(a, b) for a in claims for b in previous["claims"])
                ):
                    raise AdmissionError("project, path claim or port already reserved")
            rows = [*state["runs"].values(), row]
            if _memory_available() < sum(r["memory"] for r in rows) + max(
                r["memory_floor"] for r in rows
            ):
                raise AdmissionError("memory reservation and host floor unavailable")
            _check_disk(rows, self.root)
            _ports_available(ports)
            token = secrets.token_hex(16)
            state["runs"][token] = row
            self._write(dfd, state)
        return Lease(self, token, row)


def _invalid_constant():
    raise AdmissionError("non-finite registry number")


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise AdmissionError("duplicate registry key")
        result[key] = value
    return result


def _validate_row(token, row):
    fields = {
        "project",
        "memory",
        "disk",
        "memory_floor",
        "disk_floor",
        "claims",
        "ports",
        "controller",
        "owner_scope",
        "created",
    }
    if not isinstance(row, dict) or set(row) != fields:
        raise AdmissionError("invalid lease record")
    _validate_identity(row["controller"])
    _validate_scope(row["owner_scope"])
    for key in ("memory", "disk", "memory_floor", "disk_floor"):
        _number(row[key])
    if (
        not isinstance(row["project"], str)
        or not row["project"].startswith("/")
        or not isinstance(row["claims"], list)
        or not row["claims"]
        or len(row["claims"]) > 128
        or any(not isinstance(p, str) or not p.startswith("/") for p in row["claims"])
        or row["project"] not in row["claims"]
        or not isinstance(row["ports"], list)
        or len(row["ports"]) > 64
        or any(type(p) is not int or not 1 <= p <= 65535 for p in row["ports"])
        or len(set(row["ports"])) != len(row["ports"])
        or type(row["created"]) not in (int, float)
        or not math.isfinite(row["created"])
        or any(
            str(PurePosixPath(p)) != p or ".." in PurePosixPath(p).parts
            for p in row["claims"]
        )
    ):
        raise AdmissionError("invalid lease reservations")


class Lease:
    def __init__(self, registry, token, row):
        self.registry, self.token, self._row = registry, token, copy.deepcopy(row)
        self.closed = False
        self.receipt = dict(
            token=token,
            project=row["project"],
            controller=copy.deepcopy(row["controller"]),
            ownerScope=copy.deepcopy(row["owner_scope"]),
            claims=list(row["claims"]),
            memoryBytes=row["memory"],
            diskBytes=row["disk"],
            memoryFloorBytes=row["memory_floor"],
            diskFloorBytes=row["disk_floor"],
            ports=list(row["ports"]),
            version=VERSION,
        )

    def _owned(self, state):
        if identity() != self._row["controller"]:
            raise AdmissionError("only the original live controller owns this lease")
        if state["runs"].get(self.token) != self._row:
            raise AdmissionError("lease record changed or missing")
        _verify_unit(self._row["owner_scope"])
        _verify_supervisors(self._row)
        return _verify_live_scope(self._row)

    def check(self):
        if self.closed:
            raise AdmissionError("lease is closed")
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            self._owned(state)
            self.registry._retire_ended(dfd, state)
            rows = list(state["runs"].values())
            if _memory_available() < sum(row["memory"] for row in rows) + max(
                row["memory_floor"] for row in rows
            ):
                raise AdmissionError("host memory floor exhausted")
            _check_disk(rows, self.registry.root)

    def release(self, identities, cleanup_verified):
        if cleanup_verified is not True:
            raise AdmissionError("cleanup not verified; lease retained")
        if not isinstance(identities, list) or len(identities) > MAX_MEMBERS:
            raise AdmissionError("bounded cleanup identities required")
        if self.closed:
            return
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            scope = self._owned(state)
            allowed = {
                row["pid"]
                for row in [
                    self._row["controller"],
                    *self._row["owner_scope"]["supervisors"],
                ]
            }
            if scope["members"] - allowed:
                raise AdmissionError("owned workers remain; lease retained")
            for old in identities:
                if not isinstance(old, dict) or type(old.get("pid")) is not int:
                    raise AdmissionError("invalid cleanup identity")
                actual = identity(old["pid"])
                if actual is not None:
                    if str(old.get("start")) != actual["start"]:
                        raise AdmissionError(
                            "cleanup PID identity changed; lease retained"
                        )
                    if actual["pid"] not in allowed:
                        raise AdmissionError(
                            "unreaped owned identity remains; lease retained"
                        )
            del state["runs"][self.token]
            self.registry._write(dfd, state)
            self.closed = True


def install(destination=None):
    """Install a new content-addressed, user-owned module; never replace collisions."""
    source = Path(__file__).read_bytes()
    digest = hashlib.sha256(source).hexdigest()
    directory = (
        Path(destination)
        if destination is not None
        else Path.home()
        / ".local/share"
        / ("weeb-test-admission-v" + ARTIFACT_VERSION + "-" + digest[:12])
    )
    if (
        not directory.is_absolute()
        or directory.name
        != "weeb-test-admission-v" + ARTIFACT_VERSION + "-" + digest[:12]
    ):
        raise AdmissionError("exact content-addressed installation directory required")
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    meta = directory.lstat()
    if (
        not stat.S_ISDIR(meta.st_mode)
        or meta.st_uid != os.getuid()
        or stat.S_IMODE(meta.st_mode) != 0o700
    ):
        raise AdmissionError("private installation directory required")
    target = directory / "host_admission.py"
    if target.exists() or target.is_symlink():
        fd = os.open(target, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as stream:
            Registry._private(stream.fileno())
            if stream.read(MAX_RECORD + 1) != source:
                raise AdmissionError("installation collision; retained unchanged")
    else:
        fd, temporary = tempfile.mkstemp(prefix=".install-", dir=directory)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(source)
                stream.flush()
                os.fsync(stream.fileno())
            os.link(temporary, target, follow_symlinks=False)
        finally:
            os.unlink(temporary)
        dfd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    print(
        json.dumps(
            dict(
                version=VERSION,
                artifactVersion=ARTIFACT_VERSION,
                path=str(target),
                sha256=digest,
            )
        )
    )


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["--initialize-registry"]:
        registry = Registry()
        registry.initialize()
        print(
            json.dumps(
                dict(version=VERSION, registry=str(registry.root), initialized=True)
            )
        )
    elif len(sys.argv) in (2, 3) and sys.argv[1] == "--install":
        install(sys.argv[2] if len(sys.argv) == 3 else None)
    else:
        raise SystemExit(
            "usage: host-test-admission.py --install [directory] | --initialize-registry"
        )
