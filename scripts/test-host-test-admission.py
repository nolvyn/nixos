#!/usr/bin/env python3
"""Disposable safeguards for the versioned shared admission module."""

import contextlib
import hashlib
import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).with_name("host-test-admission.py")
spec = importlib.util.spec_from_file_location("host_admission", SOURCE)
h = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = h
spec.loader.exec_module(h)
REAL_VERIFY_LIVE_SCOPE = h._verify_live_scope


def observation(row):
    return dict(members={row["controller"]["pid"]}, populated=True)


class HostUidMappingTests(unittest.TestCase):
    def verify(
        self,
        mapping="0 1000 1\n",
        uid=0,
        euid=None,
        group="/user.slice/user-1000.slice/user@1000.service/app.slice/test.scope",
        owner=0,
        mode=0o40700,
        changed_mapping=None,
    ):
        from types import SimpleNamespace

        reads = 0

        def read(path, limit=65536):
            nonlocal reads
            if path == "/proc/self/uid_map":
                reads += 1
                return (
                    changed_mapping
                    if changed_mapping is not None and reads > 1
                    else mapping
                )
            if path.endswith("/cgroup"):
                return "0::" + group + "\n"
            raise AssertionError(path)

        with (
            patch.object(h, "_read", side_effect=read),
            patch.object(h.os, "getuid", return_value=uid),
            patch.object(h.os, "geteuid", return_value=uid if euid is None else euid),
            patch.object(
                Path, "lstat", return_value=SimpleNamespace(st_mode=mode, st_uid=owner)
            ),
            patch.object(
                Path, "resolve", autospec=True, side_effect=lambda path, **kwargs: path
            ),
        ):
            return h._host_uid()

    def test_initial_namespace_and_single_root_map_bind_same_host(self):
        self.assertEqual(self.verify(), 1000)
        self.assertEqual(
            self.verify(mapping="0 0 4294967295\n", uid=1000, owner=1000), 1000
        )

    def test_wrong_scope_owner_and_runtime_owner_refused(self):
        for changes in [
            dict(group="/user.slice/user-0.slice/user@0.service/test.scope"),
            dict(owner=65534),
            dict(mode=0o40755),
        ]:
            with self.subTest(changes=changes), self.assertRaises(h.AdmissionError):
                self.verify(**changes)

    def test_ambiguous_unsupported_or_changed_maps_fail_closed(self):
        for mapping in [
            "0 0 1\n",
            "0 1000 1\n1 2000 1\n",
            "1000 0 1\n",
            "0 1000 2\n",
            "0 nope 1\n",
            "0 01000 1\n",
            "0 4294967296 1\n",
        ]:
            with self.subTest(mapping=mapping), self.assertRaises(h.AdmissionError):
                self.verify(mapping=mapping)
        with self.assertRaises(h.AdmissionError):
            self.verify(changed_mapping="0 2000 1\n")
        with self.assertRaises(h.AdmissionError):
            self.verify(euid=1000)

    def test_environment_cannot_select_host_uid(self):
        with patch.dict(
            os.environ, {"NEMURE_HOST_UID": "0", "XDG_RUNTIME_DIR": "/tmp/foreign"}
        ):
            self.assertEqual(self.verify(), 1000)

    def test_default_registry_keeps_host_uid_in_namespace(self):
        # Do not create an alternate live registry; refuse immediately after
        # observing the selected default path in a simulated namespace.
        captured = []

        def mkdir(path, **kwargs):
            captured.append(str(path))
            raise OSError("fixture stops before any filesystem write")

        with (
            patch.object(h, "_host_uid", return_value=1000),
            patch.object(h.os, "getuid", return_value=0),
            patch.object(Path, "mkdir", autospec=True, side_effect=mkdir),
        ):
            with self.assertRaises(OSError):
                h.Registry()
        self.assertEqual(captured, ["/tmp/weeb-test-admission-1000"])


class ScopeTests(unittest.TestCase):
    def setUp(self):
        actual = h.identity()
        self.controller = dict(actual, pid=101)
        self.child = dict(actual, pid=202, start=str(int(actual["start"]) + 1))
        self.row = dict(
            controller=self.controller,
            owner_scope=dict(
                unit="fixture.scope", path="/fixture.scope", supervisors=[]
            ),
        )

    def census(self, *pids):
        return dict(members=set(pids), populated=True)

    def test_fresh_closing_census_required_for_disappeared_process(self):
        with (
            patch.object(
                h,
                "_scope_census",
                side_effect=[self.census(101, 202), self.census(101)],
            ) as call,
            patch.object(
                h,
                "identity",
                side_effect=lambda p: self.controller if p == 101 else None,
            ),
        ):
            self.assertEqual(h._verify_live_scope(self.row), self.census(101))
        self.assertEqual(call.call_count, 2)

    def test_unknown_identity_reappearing_is_rejected(self):
        children = iter([None, self.child])
        with (
            patch.object(h, "_scope_census", return_value=self.census(101, 202)),
            patch.object(
                h,
                "identity",
                side_effect=lambda p: self.controller if p == 101 else next(children),
            ),
        ):
            with self.assertRaisesRegex(h.AdmissionError, "identity changed"):
                h._verify_live_scope(self.row)

    def test_live_scope_escape_is_rejected(self):
        with (
            patch.object(
                h,
                "_scope_census",
                side_effect=[self.census(101, 202), self.census(101)],
            ),
            patch.object(
                h,
                "identity",
                side_effect=lambda p: self.controller if p == 101 else self.child,
            ),
            patch.object(h, "_pid_scope", return_value="/outside.scope"),
        ):
            with self.assertRaisesRegex(h.AdmissionError, "live process left"):
                h._verify_live_scope(self.row)

    def test_retained_pid_reuse_is_rejected(self):
        children = iter([self.child, dict(self.child, start="999999999")])
        with (
            patch.object(h, "_scope_census", return_value=self.census(101, 202)),
            patch.object(
                h,
                "identity",
                side_effect=lambda p: self.controller if p == 101 else next(children),
            ),
        ):
            with self.assertRaisesRegex(h.AdmissionError, "identity changed"):
                h._verify_live_scope(self.row)

    def test_four_paired_attempts_only(self):
        with (
            patch.object(
                h, "_scope_census", return_value=self.census(101, 202)
            ) as call,
            patch.object(
                h,
                "identity",
                side_effect=lambda p: self.controller if p == 101 else None,
            ),
            patch.object(h.time, "sleep") as pause,
        ):
            with self.assertRaisesRegex(h.AdmissionError, "four complete censuses"):
                h._verify_live_scope(self.row)
        self.assertEqual(call.call_count, 8)
        self.assertEqual([item.args for item in pause.call_args_list], [(0.005,)] * 3)

    def test_stable_pair_has_no_pause(self):
        with (
            patch.object(h, "_scope_census", return_value=self.census(101)) as census,
            patch.object(h, "identity", return_value=self.controller),
            patch.object(h.time, "sleep") as pause,
        ):
            self.assertEqual(h._verify_live_scope(self.row), self.census(101))
        self.assertEqual(census.call_count, 2)
        pause.assert_not_called()

    def test_settling_burst_requires_another_complete_pair(self):
        settled = False
        observations = []

        def census(scope):
            observations.append(settled)
            return (
                self.census(101)
                if settled or len(observations) % 2
                else self.census(101, 202)
            )

        def pause(delay):
            nonlocal settled
            self.assertEqual(delay, 0.005)
            settled = True

        with (
            patch.object(h, "_scope_census", side_effect=census),
            patch.object(
                h,
                "identity",
                side_effect=lambda pid: self.controller if pid == 101 else self.child,
            ),
            patch.object(h.time, "sleep", side_effect=pause),
        ):
            self.assertEqual(h._verify_live_scope(self.row), self.census(101))
        self.assertEqual(observations, [False, False, True, True])

    def test_burst_ending_in_disappearance_still_requires_complete_census(self):
        children = iter([self.child] * 4 + [None] * 2)
        last = iter([dict(self.child, pid=306), None])
        pairs = [
            self.census(101, 202),
            self.census(101, 202, 303),
            self.census(101, 202),
            self.census(101, 202, 304),
            self.census(101, 202),
            self.census(101, 305),
            self.census(101, 306),
            self.census(101, 306),
        ]

        def identity(pid):
            if pid == 101:
                return self.controller
            if pid == 202:
                return next(children)
            if pid == 303:
                return dict(self.child, pid=303)
            if pid == 306:
                return next(last)
            return None

        with (
            patch.object(h, "_scope_census", side_effect=pairs) as census,
            patch.object(h, "identity", side_effect=identity),
            patch.object(h.time, "sleep") as pause,
        ):
            with self.assertRaisesRegex(h.AdmissionError, "four complete censuses"):
                h._verify_live_scope(self.row)
        self.assertEqual(census.call_count, 8)
        self.assertEqual(pause.call_count, 3)

    def test_permission_failure_is_not_absence(self):
        def ident(pid):
            if pid == 101:
                return self.controller
            raise PermissionError("fixture")

        with (
            patch.object(h, "_scope_census", return_value=self.census(101, 202)),
            patch.object(h, "identity", side_effect=ident),
        ):
            with self.assertRaises(PermissionError):
                h._verify_live_scope(self.row)

    def test_identity_of_real_unreaped_zombie(self):
        pid = os.fork()
        if pid == 0:
            os._exit(0)
        try:
            deadline = time.monotonic() + 3
            while h._stat(pid)[1] != "Z" and time.monotonic() < deadline:
                time.sleep(0.01)
            row = h.identity(pid)
            self.assertEqual(set(row), {"pid", "start", "boot", "pidns"})
            self.assertEqual(row["pidns"], h.identity()["pidns"])
            scope = dict(path=h._pid_scope(pid))
            self.assertTrue(h._omitted_identity_retryable(pid, row, scope))
        finally:
            os.waitpid(pid, 0)
        self.assertIsNone(h.identity(pid))

    def test_live_nonterminal_is_not_retryable(self):
        row = h.identity()
        self.assertFalse(
            h._omitted_identity_retryable(
                os.getpid(), row, dict(path=h._pid_scope(os.getpid()))
            )
        )

    def test_reaped_omitted_child_requires_fresh_complete_pair(self):
        pid = os.fork()
        if pid == 0:
            os._exit(0)
        reaped = False
        try:
            deadline = time.monotonic() + 2
            while h._stat(pid)[1] != "Z":
                if time.monotonic() >= deadline:
                    self.fail("fixture child did not exit")
                time.sleep(0.001)
            controller = h.identity()
            scope = dict(
                path=h._pid_scope(os.getpid()), unit="fixture.scope", supervisors=[]
            )
            row = dict(controller=controller, owner_scope=scope)
            original_stat, original_omitted = h._stat, h._omitted_identity_retryable
            inside, observations, terminal_reads = False, [], 0

            def stat(target):
                nonlocal reaped, terminal_reads
                result = original_stat(target)
                if inside and target == pid:
                    terminal_reads += 1
                    if terminal_reads == 3:
                        os.waitpid(pid, 0)
                        reaped = True
                return result

            def omitted(*args):
                nonlocal inside
                inside = True
                try:
                    return original_omitted(*args)
                finally:
                    inside = False

            def census(scope):
                value = dict(
                    members={controller["pid"], pid}
                    if not observations
                    else {controller["pid"]},
                    populated=True,
                )
                observations.append(value)
                return value

            with (
                patch.object(h, "_stat", side_effect=stat),
                patch.object(h, "_omitted_identity_retryable", side_effect=omitted),
                patch.object(h, "_scope_census", side_effect=census),
            ):
                self.assertEqual(
                    h._verify_live_scope(row)["members"], {controller["pid"]}
                )
            self.assertTrue(reaped)
            self.assertEqual(len(observations), 4)
        finally:
            if not reaped:
                os.waitpid(pid, 0)

    def test_direct_disappearance_remains_a_refusal(self):
        with patch.object(h, "identity", return_value=None):
            with self.assertRaises(h.CensusProcessGone):
                h._omitted_identity_retryable(202, self.child, self.row["owner_scope"])

    def test_missing_metadata_for_existing_pid_is_not_disappearance(self):
        with (
            patch.object(h, "identity", return_value=self.child),
            patch.object(h, "_pid_scope", side_effect=FileNotFoundError()),
        ):
            with self.assertRaises(h.AdmissionError) as raised:
                h._omitted_identity_retryable(202, self.child, self.row["owner_scope"])
        self.assertNotIsInstance(raised.exception, h.CensusProcessGone)

    def test_disappearance_does_not_mask_another_worker_fault(self):
        class OrderedMembers(set):
            def __iter__(self):
                return iter(sorted(set.__iter__(self)))

        for error in [
            h.AdmissionError("observed identity reuse"),
            PermissionError("fixture denial"),
        ]:

            def omitted(pid, expected, scope):
                if pid == 202:
                    raise h.CensusProcessGone(pid)
                raise error

            with (
                self.subTest(error=type(error).__name__),
                patch.object(
                    h,
                    "_scope_census",
                    side_effect=[
                        dict(members=OrderedMembers([101, 202, 303]), populated=True),
                        self.census(101),
                    ],
                ),
                patch.object(
                    h,
                    "identity",
                    side_effect=lambda pid: (
                        self.controller if pid == 101 else dict(self.child, pid=pid)
                    ),
                ),
                patch.object(h, "_omitted_identity_retryable", side_effect=omitted),
                patch.object(h.time, "sleep") as pause,
            ):
                with self.assertRaises(type(error)) as raised:
                    h._verify_live_scope(self.row)
                self.assertIs(raised.exception, error)
                pause.assert_not_called()

    def test_repeated_omission_disappearance_exhausts_four_pairs(self):
        pairs = [self.census(101, 202), self.census(101)] * 4
        with (
            patch.object(h, "_scope_census", side_effect=pairs) as census,
            patch.object(
                h,
                "identity",
                side_effect=lambda pid: self.controller if pid == 101 else self.child,
            ),
            patch.object(
                h, "_omitted_identity_retryable", side_effect=h.CensusProcessGone(202)
            ),
            patch.object(h.time, "sleep") as pause,
        ):
            with self.assertRaisesRegex(h.AdmissionError, "four complete censuses"):
                h._verify_live_scope(self.row)
        self.assertEqual(census.call_count, 8)
        self.assertEqual(pause.call_count, 3)

    def test_unreadable_stat_propagates(self):
        with patch.object(h, "_stat", side_effect=PermissionError("fixture")):
            with self.assertRaises(PermissionError):
                h.identity()


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="test-admission-v2-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        unit = "weeb-test-admission-" + "a" * 32 + ".scope"
        self.scope = dict(
            unit=unit,
            path=f"/user.slice/user-{os.getuid()}.slice/user@{os.getuid()}.service/app.slice/{unit}",
            supervisors=[],
        )
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        for name, value in [
            ("_verify_unit", None),
            ("_pid_scope", self.scope["path"]),
            ("_memory_available", 1000),
            ("_disk_available", 1000),
        ]:
            self.stack.enter_context(patch.object(h, name, return_value=value))
        self.stack.enter_context(
            patch.object(h, "_verify_live_scope", side_effect=observation)
        )
        self.registry = h.Registry(self.root / "registry")

    def admit(self, **changes):
        args = dict(
            project=self.project,
            memory=100,
            disk=100,
            memory_floor=100,
            disk_floor=100,
            claims=[self.project],
            ports=[],
            owner_scope=self.scope,
        )
        args.update(changes)
        return self.registry.admit(**args)

    def state(self):
        return json.loads((self.registry.root / "state.json").read_text())

    def test_normal_bootstrap_is_idempotent_and_preserves_leases(self):
        self.registry.initialize()
        self.assertEqual(self.state()["runs"], {})
        lease = self.admit()
        before = (self.registry.root / "state.json").read_bytes()
        self.registry.initialize()
        self.assertEqual((self.registry.root / "state.json").read_bytes(), before)
        lease.release([], True)

    def test_disk_checks_all_claimed_filesystems_at_admit_and_check(self):
        with patch.object(
            h,
            "_disk_available",
            side_effect=lambda path: 199 if Path(path) == self.project else 1000,
        ):
            with self.assertRaises(h.AdmissionError):
                self.admit()
        lease = self.admit()
        with patch.object(
            h,
            "_disk_available",
            side_effect=lambda path: 199 if Path(path) == self.project else 1000,
        ):
            with self.assertRaises(h.AdmissionError):
                lease.check()
        lease.release([], True)

    def test_lock_holder_crash_does_not_abandon_flock(self):
        child = os.fork()
        if child == 0:
            with self.registry._locked():
                os._exit(8)
        os.waitpid(child, 0)
        self.registry.initialize()
        lease = self.admit()
        lease.release([], True)

    def test_roundtrip_and_receipt(self):
        lease = self.admit()
        self.assertEqual(lease.receipt["controller"], h.identity())
        self.assertEqual(lease.receipt["ownerScope"], self.scope)
        self.assertEqual(len(lease.token), 32)
        lease.check()
        lease.release([], True)
        self.assertTrue(lease.closed)
        self.assertEqual(self.state()["runs"], {})
        lease.release([], True)

    def test_memory_disk_reservations_remain_in_checks(self):
        lease = self.admit()
        for metric in ["_memory_available", "_disk_available"]:
            with self.subTest(metric=metric), patch.object(h, metric, return_value=199):
                with self.assertRaises(h.AdmissionError):
                    lease.check()
        lease.release([], True)

    def test_aggregate_reservations_and_maximum_floor(self):
        first = self.admit(memory=500, disk=500)
        second_project = self.root / "other"
        second_project.mkdir()
        for changes in [dict(memory=401), dict(disk=401), dict(memory_floor=401)]:
            with self.subTest(changes=changes), self.assertRaises(h.AdmissionError):
                self.admit(project=second_project, claims=[second_project], **changes)
        self.assertEqual(len(self.state()["runs"]), 1)
        first.release([], True)

    def test_overlapping_claims_and_root_claim(self):
        lease = self.admit()
        other = self.root / "other"
        other.mkdir()
        with self.assertRaises(h.AdmissionError):
            self.admit(project=other, claims=[other, self.project / "child"])
        self.assertTrue(h._overlap("/", str(other)))
        lease.release([], True)

    def test_false_cleanup_and_unlisted_live_worker_retain_lease(self):
        lease = self.admit()
        with self.assertRaises(h.AdmissionError):
            lease.release([], False)
        with patch.object(
            h,
            "_verify_live_scope",
            return_value=dict(members={os.getpid(), 99999}, populated=True),
        ):
            with self.assertRaisesRegex(h.AdmissionError, "workers remain"):
                lease.release([], True)
        self.assertIn(lease.token, self.state()["runs"])
        lease.release([], True)

    def test_pid_reuse_in_cleanup_is_rejected(self):
        lease = self.admit()
        with self.assertRaisesRegex(h.AdmissionError, "PID identity changed"):
            lease.release([dict(pid=os.getpid(), start="999999")], True)
        lease.release([], True)

    def test_foreign_controller_cannot_release(self):
        lease = self.admit()
        actual = h.identity()
        with patch.object(h, "identity", return_value=dict(actual, start="999999")):
            with self.assertRaises(h.AdmissionError):
                lease.release([], True)
        self.assertIn(lease.token, self.state()["runs"])
        lease.release([], True)

    def test_registry_corruption_foreign_boot_and_namespace_fail_closed(self):
        lease = self.admit()
        original = (self.registry.root / "state.json").read_bytes()
        marker = self.registry.root / "lock"
        committed = marker.read_bytes()
        for payload in [
            b"{",
            b'{"version":1,"runs":{}}',
            b'{"version":2,"version":2}',
            original.replace(
                h.identity()["boot"].encode(), b"00000000-0000-0000-0000-000000000000"
            ),
            original.replace(h.identity()["pidns"].encode(), b"pid:[0]"),
            original.replace(b'"created":', b'"bad":NaN,"created":'),
        ]:
            (self.registry.root / "state.json").write_bytes(payload)
            marker.write_bytes(
                b"v2-committed " + hashlib.sha256(payload).hexdigest().encode() + b"\n"
            )
            with self.assertRaises((ValueError, h.AdmissionError)):
                self.admit()
            self.assertEqual((self.registry.root / "state.json").read_bytes(), payload)
        (self.registry.root / "state.json").write_bytes(original)
        marker.write_bytes(committed)
        lease.release([], True)

    def test_foreign_empty_registry_is_rejected_before_admission(self):
        self.registry.initialize()
        path = self.registry.root / "state.json"
        marker = self.registry.root / "lock"
        original = path.read_bytes()
        committed = marker.read_bytes()
        for field, value in [
            ("boot", "00000000-0000-0000-0000-000000000000"),
            ("pidns", "pid:[0]"),
        ]:
            state = json.loads(original)
            self.assertEqual(state["runs"], {})
            state[field] = value
            payload = (json.dumps(state, sort_keys=True) + "\n").encode()
            provenance = (
                b"v2-committed " + hashlib.sha256(payload).hexdigest().encode() + b"\n"
            )
            path.write_bytes(payload)
            marker.write_bytes(provenance)
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(
                    h.AdmissionError, "foreign boot or PID namespace"
                ),
            ):
                self.registry.initialize()
            self.assertEqual(path.read_bytes(), payload)
            self.assertEqual(marker.read_bytes(), provenance)
        path.write_bytes(original)
        marker.write_bytes(committed)
        self.registry.initialize()

    def test_missing_committed_state_is_not_reset(self):
        self.admit()
        path = self.registry.root / "state.json"
        path.rename(self.root / "preserved-state.json")
        with self.assertRaisesRegex(
            h.AdmissionError, "committed registry state missing"
        ):
            self.admit()
        self.assertFalse(path.exists())

    def test_atomic_replace_failure_preserves_previous_state(self):
        lease = self.admit()
        before = (self.registry.root / "state.json").read_bytes()
        with patch.object(h.os, "replace", side_effect=OSError("fixture")):
            with self.assertRaises(OSError):
                lease.release([], True)
        self.assertFalse(lease.closed)
        self.assertEqual((self.registry.root / "state.json").read_bytes(), before)
        with self.assertRaisesRegex(h.AdmissionError, "pending or"):
            lease.check()

    def test_pending_digest_mismatch_and_failed_fsync_fail_closed(self):
        lease = self.admit()
        path = self.registry.root / "state.json"
        marker = self.registry.root / "lock"
        original, committed = path.read_bytes(), marker.read_bytes()
        for value in (b"v2-pending\n", b"v2-committed " + b"0" * 64 + b"\n"):
            marker.write_bytes(value)
            with self.assertRaises(h.AdmissionError):
                lease.check()
            self.assertEqual(path.read_bytes(), original)
        marker.write_bytes(committed)
        fsync = os.fsync
        for fail_at in (1, 2, 3, 4):
            calls = 0

            def injected(fd):
                nonlocal calls
                calls += 1
                if calls == fail_at:
                    raise OSError("fixture fsync failure")
                return fsync(fd)

            with patch.object(h.os, "fsync", side_effect=injected):
                with self.assertRaises(OSError):
                    lease.release([], True)
            self.assertFalse(lease.closed)
            with self.assertRaises(h.AdmissionError):
                self.admit()
            # Explicit restoration of disposable fixture, not production recovery.
            path.write_bytes(original)
            marker.write_bytes(committed)
            self.registry = h.Registry(self.registry.root)
            lease.registry = self.registry
        lease.release([], True)

    def test_registry_links_permissions_and_hardlinks_refused(self):
        alias = self.root / "alias"
        alias.symlink_to(self.registry.root)
        with self.assertRaises(h.AdmissionError):
            h.Registry(alias)
        lock = self.registry.root / "lock"
        lock.symlink_to(self.root / "absent")
        with self.assertRaises(OSError):
            self.admit()
        lock.unlink()
        lock.write_text("")
        lock.chmod(0o644)
        with self.assertRaises(h.AdmissionError):
            self.admit()
        lock.chmod(0o600)
        os.link(lock, self.root / "lock-link")
        with self.assertRaises(h.AdmissionError):
            self.admit()

    def test_bounded_lock_wait(self):
        import fcntl

        lock = self.registry.root / "lock"
        fd = os.open(lock, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            with patch.object(h.time, "monotonic", side_effect=[0, 4]):
                with self.assertRaisesRegex(h.AdmissionError, "deadline"):
                    self.admit()
        finally:
            os.close(fd)

    def test_tcp_and_udp_occupancy(self):
        for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
            with socket.socket(socket.AF_INET, kind) as sock:
                sock.bind(("127.0.0.1", 0))
                with self.assertRaises(h.AdmissionError):
                    self.admit(ports=[sock.getsockname()[1]])

    def test_concurrent_admission_has_one_winner(self):
        ctx = multiprocessing.get_context("fork")
        queue, done = ctx.Queue(), ctx.Event()

        def contender():
            try:
                lease = self.admit()
            except h.AdmissionError:
                queue.put("blocked")
                return
            queue.put("admitted")
            if done.wait(10):
                lease.release([], True)

        workers = [ctx.Process(target=contender) for _ in range(8)]
        try:
            for worker in workers:
                worker.start()
            outcomes = [queue.get(timeout=10) for _ in workers]
            self.assertEqual(outcomes.count("admitted"), 1)
            self.assertEqual(len(self.state()["runs"]), 1)
        finally:
            done.set()
            for worker in workers:
                worker.join(timeout=10)
                if worker.is_alive():
                    worker.kill()
                    worker.join()
        self.assertTrue(all(worker.exitcode == 0 for worker in workers))
        self.assertEqual(self.state()["runs"], {})

    def abandon(self, **changes):
        child = os.fork()
        if child == 0:
            self.admit(**changes)
            os._exit(7)
        os.waitpid(child, 0)
        return self.state()["runs"]

    def test_crashed_controller_no_longer_blocks_same_project(self):
        previous = self.abandon()
        lease = self.admit()
        self.assertEqual(set(self.state()["runs"]), {lease.token})
        archives = list(self.registry.root.glob("retired-*.json"))
        self.assertEqual(len(archives), 1)
        evidence = json.loads(archives[0].read_text())
        self.assertEqual(evidence["row"], next(iter(previous.values())))
        self.assertEqual(evidence["token"], next(iter(previous)))
        self.assertFalse(evidence["cleanupVerified"])
        self.assertEqual(archives[0].stat().st_mode & 0o777, 0o600)
        lease.release([], True)

    def test_abandoned_resources_do_not_count_against_new_admission(self):
        self.abandon(memory=600, disk=600)
        other = self.root / "other-project"
        other.mkdir()
        lease = self.admit(project=other, claims=[other], memory=400, disk=400)
        lease.check()
        lease.release([], True)

    def test_orphan_scope_workers_keep_reservation(self):
        previous = self.abandon()
        with patch.object(h, "_scope_census", return_value=dict(members={99999}, populated=True)):
            with self.assertRaisesRegex(h.AdmissionError, "already reserved"):
                self.admit()
        self.assertEqual(self.state()["runs"], previous)

    def test_unreadable_abandoned_scope_is_not_retirement(self):
        previous = self.abandon()
        with patch.object(h, "_scope_census", side_effect=PermissionError("fixture")):
            with self.assertRaises(PermissionError):
                self.admit()
        self.assertEqual(self.state()["runs"], previous)

    def test_empty_scope_can_retire_without_claiming_cleanup(self):
        self.abandon()
        with patch.object(h, "_scope_census", return_value=dict(members=set(), populated=False)) as census:
            lease = self.admit()
        self.assertEqual(census.call_count, 6)
        lease.release([], True)

    def test_scope_repopulation_between_observations_retains_reservation(self):
        previous = self.abandon()
        with patch.object(h, "_scope_census", side_effect=[
            dict(members=set(), populated=False),
            dict(members={99999}, populated=True),
        ]):
            with self.assertRaisesRegex(h.AdmissionError, "already reserved"):
                self.admit()
        self.assertEqual(self.state()["runs"], previous)

    def test_lease_check_ignores_newly_stale_resource_charge(self):
        other = self.root / "other-project"
        other.mkdir()
        lease = self.admit(memory=400)
        self.abandon(project=other, claims=[other], memory=400)
        with patch.object(h, "_memory_available", return_value=501):
            lease.check()
        lease.release([], True)

    def test_reused_pid_retires_old_accounting_without_signaling_replacement(self):
        previous = self.abandon()
        token = next(iter(previous))
        replacement = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"])
        self.addCleanup(lambda: (replacement.terminate(), replacement.wait()) if replacement.poll() is None else None)
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            old = dict(h.identity(replacement.pid), start="1")
            state["runs"][token]["controller"] = old
            self.registry._write(dfd, state)
        lease = self.admit()
        self.assertIsNone(replacement.poll())
        self.assertNotIn(token, self.state()["runs"])
        lease.release([], True)

    def test_reused_pid_does_not_override_populated_old_scope(self):
        previous = self.abandon()
        token = next(iter(previous))
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            state["runs"][token]["controller"] = dict(h.identity(), start="1")
            self.registry._write(dfd, state)
        with patch.object(h, "_scope_census", return_value=dict(members={99999}, populated=True)):
            with self.assertRaisesRegex(h.AdmissionError, "already reserved"):
                self.admit()
        self.assertIn(token, self.state()["runs"])

    def test_reused_pid_populated_scope_does_not_veto_unrelated_work(self):
        previous = self.abandon()
        token = next(iter(previous))
        worker = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"])
        self.addCleanup(lambda: (worker.terminate(), worker.wait()) if worker.poll() is None else None)
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            state["runs"][token]["controller"] = dict(h.identity(), start="1")
            self.registry._write(dfd, state)
        other = self.root / "other-project"
        other.mkdir()
        other_unit = "weeb-test-admission-" + "b" * 32 + ".scope"
        other_scope = dict(self.scope, unit=other_unit,
                           path=self.scope["path"].replace(self.scope["unit"], other_unit))
        def census(scope):
            members = {worker.pid} if scope == self.scope else {os.getpid()}
            return dict(members=members, populated=True)
        with patch.object(h, "_scope_census", side_effect=census), patch.object(h, "_verify_live_scope", REAL_VERIFY_LIVE_SCOPE), patch.object(h, "_pid_scope", return_value=other_scope["path"]):
            lease = self.admit(project=other, claims=[other], owner_scope=other_scope)
            lease.check()
            self.assertIn(token, self.state()["runs"])
            self.assertIsNone(worker.poll())
            lease.release([], True)

    def test_foreign_controller_identity_domain_is_not_retired(self):
        previous = self.abandon()
        token = next(iter(previous))
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            state["runs"][token]["controller"]["pidns"] = "pid:[1]"
            self.registry._write(dfd, state)
        with self.assertRaisesRegex(h.AdmissionError, "foreign controller identity"):
            self.admit()
        self.assertIn(token, self.state()["runs"])

    def test_missing_child_file_is_not_missing_scope(self):
        previous = self.abandon()
        original_lstat = Path.lstat
        def present_root(path, *args, **kwargs):
            if str(path).startswith("/sys/fs/cgroup/"):
                return original_lstat(self.project)
            return original_lstat(path, *args, **kwargs)
        with patch.object(h, "_scope_census", side_effect=FileNotFoundError("child file")), patch.object(Path, "lstat", present_root):
            with self.assertRaisesRegex(h.AdmissionError, "incomplete abandoned scope"):
                self.admit()
        self.assertEqual(self.state()["runs"], previous)

    def test_retirement_compacts_at_the_registry_row_bound(self):
        previous = self.abandon()
        row = next(iter(previous.values()))
        with self.registry._locked() as dfd:
            state = self.registry._load(dfd)
            state["runs"] = {format(index, "032x"): row for index in range(256)}
            self.registry._write(dfd, state)
        lease = self.admit()
        self.assertEqual(set(self.state()["runs"]), {lease.token})
        self.assertEqual(len(list(self.registry.root.glob("retired-*.json"))), 256)
        lease.release([], True)

    def test_populated_orphan_still_counts_against_capacity(self):
        self.abandon(memory=600)
        other = self.root / "other-project"
        other.mkdir()
        with patch.object(h, "_scope_census", return_value=dict(members={99999}, populated=True)):
            with self.assertRaisesRegex(h.AdmissionError, "memory reservation"):
                self.admit(project=other, claims=[other], memory=400)

    def test_archive_failure_does_not_mutate_registry(self):
        previous = self.abandon()
        with patch.object(self.registry, "_archive_retired", side_effect=OSError("fixture")):
            with self.assertRaises(OSError):
                self.admit()
        self.assertEqual(self.state()["runs"], previous)


class ClaimAndScopePropertiesTests(unittest.TestCase):
    def test_walk_claim_rejects_redirected_directory(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            alias = root / "alias"
            alias.symlink_to(root, target_is_directory=True)
            with self.assertRaises(h.AdmissionError):
                h._walk_claim(alias)
            result = h._walk_claim(root)
            self.assertEqual(result["kind"], "directory")
            self.assertEqual(result["ino"], root.stat().st_ino)

    def test_exact_scope_policy_is_required(self):
        unit = "weeb-test-admission-" + "b" * 32 + ".scope"
        scope = dict(
            unit=unit,
            path=f"/user.slice/user-{os.getuid()}.slice/user@{os.getuid()}.service/app.slice/{unit}",
            supervisors=[],
        )
        values = dict(
            Id=unit,
            ControlGroup=scope["path"],
            Delegate="no",
            KillMode="control-group",
            LoadState="loaded",
            ActiveState="active",
        )
        with patch.object(h, "_scope_properties", return_value=values):
            h._verify_unit(scope)
        for key, value in [
            ("Delegate", "yes"),
            ("KillMode", "process"),
            ("ControlGroup", "/elsewhere"),
            ("ActiveState", "inactive"),
        ]:
            with patch.object(
                h, "_scope_properties", return_value=dict(values, **{key: value})
            ):
                with self.assertRaises(h.AdmissionError):
                    h._verify_unit(scope)


class InstallationTests(unittest.TestCase):
    def test_private_exact_copy_idempotent_and_collision_retained(self):
        digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root) / (
                "weeb-test-admission-v" + h.ARTIFACT_VERSION + "-" + digest[:12]
            )
            for _ in range(2):
                subprocess.run(
                    [sys.executable, str(SOURCE), "--install", str(directory)],
                    check=True,
                    stdout=subprocess.DEVNULL,
                )
            target = directory / "host_admission.py"
            self.assertEqual(target.read_bytes(), SOURCE.read_bytes())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            target.write_text("distinct preserved contents")
            result = subprocess.run(
                [sys.executable, str(SOURCE), "--install", str(directory)],
                capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_text(), "distinct preserved contents")


if __name__ == "__main__":
    unittest.main()
