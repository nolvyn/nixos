#!/usr/bin/env python3
"""Linux-safe mocked tests: never invoke Xcode, sudo, a download or a simulator."""

import argparse
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "setup", Path(__file__).with_name("astraeus-dev-setup.py")
)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)

RUNTIME = {
    "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
    "version": "27.0",
    "isAvailable": True,
    "bundlePath": "/runtime/iOS.simruntime",
    "supportedDeviceTypes": [
        {"identifier": "phone", "productFamily": "iPhone"},
        {"identifier": "tablet", "productFamily": "iPad"},
    ],
}


# Sanitized CoreSimulator image shape from the upstream tooling log at
# https://github.com/dotnet/maui/issues/32735 (not an Astraeus execution fixture).
RUNTIME_IMAGE = {
    "runtimeIdentifier": RUNTIME["identifier"],
    "runtimeBundlePath": RUNTIME["bundlePath"],
    "state": "Ready",
    "signatureState": "Verified",
    "supportedArchitectures": ["x86_64", "arm64"],
}


class AppleMock:
    def __init__(self, developer):
        self.developer = str(developer)
        self.selected = "/Library/Developer/CommandLineTools"
        self.data = {"runtimes": [copy.deepcopy(RUNTIME)], "devices": {}}
        self.calls = []
        self.license = True
        self.first_launch = False
        self.arch = "arm64"
        self.runtime_arch = "arm64"
        self.runtime_image_state = "Ready"
        self.registration_available = True
        self.streamed = []
        self.download_failure = False
        self.download_registers = True
        self.create_registers = True
        self.selection_works = True

    def __call__(self, *args, check=True, stream=False):
        self.calls.append(args)
        if stream:
            self.streamed.append(args)
        output, code = "", 0
        if args == ("/usr/bin/uname", "-m"):
            output = self.arch
        elif args[-2:] == ("-license", "check"):
            code = 0 if self.license else 1
        elif args == ("/usr/bin/xcode-select", "-p"):
            assert "DEVELOPER_DIR" not in os.environ
            output = self.selected
        elif "--switch" in args:
            if self.selection_works:
                self.selected = args[-1]
        elif "-checkFirstLaunchStatus" in args:
            code = 0 if self.first_launch else 1
        elif "-runFirstLaunch" in args:
            self.first_launch = True
        elif args[-4:] == ("-version", "-sdk", "iphonesimulator", "SDKVersion"):
            output = "27.0"
        elif args[-1] == "-version":
            output = "Xcode 27.0\nBuild version fixture"
        elif args[:3] == ("/usr/bin/xcrun", "simctl", "list"):
            output = json.dumps(self.data)
        elif args[:4] == ("/usr/bin/xcrun", "simctl", "runtime", "list"):
            output = json.dumps(
                {
                    "image-uuid": dict(
                        RUNTIME_IMAGE,
                        supportedArchitectures=[self.runtime_arch],
                        state=self.runtime_image_state,
                    )
                }
            )
        elif "-downloadPlatform" in args:
            if self.download_failure:
                raise setup.SetupError(
                    "Apple download failed: authentication/network fixture"
                )
            if self.download_registers:
                self.data["runtimes"] = [copy.deepcopy(RUNTIME)]
        elif args[:3] == ("/usr/bin/xcrun", "simctl", "create"):
            output = "UUID-" + args[-2]
            if self.create_registers:
                self.data["devices"].setdefault(args[-1], []).append(
                    {
                        "udid": output,
                        "deviceTypeIdentifier": args[-2],
                        "isAvailable": self.registration_available,
                        "name": args[-3],
                    }
                )
        else:
            raise AssertionError(f"Unexpected command: {args}")
        if code and check:
            raise setup.SetupError("mocked Apple failure")
        return subprocess.CompletedProcess(args, code, output, "")


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Xcode.app"
        developer = self.app / "Contents/Developer"
        (developer / "usr/bin").mkdir(parents=True)
        (developer / "usr/bin/xcodebuild").touch()
        self.apple = AppleMock(developer)
        self.args = argparse.Namespace(
            xcode=str(self.app), download_runtime=False, runtime=None
        )
        for target, value in [
            ("run", self.apple),
            ("sys.platform", "darwin"),
            ("os.geteuid", lambda: 501),
        ]:
            if "." in target:
                obj, attr = target.split(".")
                patcher = patch.object(getattr(setup, obj), attr, value)
            else:
                patcher = patch.object(setup, target, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        env = patch.dict(os.environ)
        env.start()
        self.addCleanup(env.stop)
        self.output = io.StringIO()

    def execute(self):
        with contextlib.redirect_stdout(self.output):
            setup.setup(self.args)

    def test_first_run_then_repeated_run_reuses_devices_and_runtime(self):
        self.execute()
        before = copy.deepcopy(self.apple.data)
        self.execute()
        self.assertEqual(before, self.apple.data)
        self.assertEqual(sum("create" in c for c in self.apple.calls), 2)
        self.assertEqual(sum("-runFirstLaunch" in c for c in self.apple.calls), 1)
        self.assertFalse(any("-downloadPlatform" in c for c in self.apple.calls))
        self.assertEqual(self.apple.selected, self.apple.developer)

    def test_explicit_download_is_still_skipped_when_registered(self):
        self.args.download_runtime = True
        self.execute()
        self.assertFalse(any("-downloadPlatform" in c for c in self.apple.calls))

    def test_existing_user_named_device_is_preserved(self):
        self.apple.data["devices"][RUNTIME["identifier"]] = [
            {
                "udid": "personal-phone",
                "deviceTypeIdentifier": "phone",
                "isAvailable": True,
                "name": "My existing phone",
                "state": "Booted",
            }
        ]
        before = copy.deepcopy(self.apple.data["devices"][RUNTIME["identifier"]][0])
        self.execute()
        self.assertEqual(before, self.apple.data["devices"][RUNTIME["identifier"]][0])
        self.assertIn("personal-phone", self.output.getvalue())
        self.assertEqual(sum("create" in c for c in self.apple.calls), 1)

    def test_unavailable_helper_named_device_is_not_duplicated_on_retries(self):
        self.apple.data["devices"][RUNTIME["identifier"]] = [
            {
                "udid": "incomplete-phone",
                "deviceTypeIdentifier": "phone",
                "isAvailable": False,
                "name": "Astraeus iPhone iOS 27.0",
            }
        ]
        before = copy.deepcopy(self.apple.data)
        for _ in range(2):
            with self.assertRaisesRegex(
                setup.SetupError, "already exists.*incomplete-phone"
            ):
                self.execute()
        self.assertEqual(before, self.apple.data)
        self.assertFalse(any("create" in c for c in self.apple.calls))

    def test_conflicting_caller_developer_dir_is_actionable_before_mutation(self):
        os.environ["DEVELOPER_DIR"] = "/other/Xcode.app/Contents/Developer"
        with self.assertRaisesRegex(
            setup.SetupError, "set -e DEVELOPER_DIR.*unset DEVELOPER_DIR"
        ):
            self.execute()
        self.assertEqual(
            os.environ["DEVELOPER_DIR"], "/other/Xcode.app/Contents/Developer"
        )
        self.assertFalse(any("/usr/bin/sudo" in c for c in self.apple.calls))

    def test_license_refusal_precedes_system_mutation(self):
        self.apple.license = False
        with self.assertRaisesRegex(setup.SetupError, "License not accepted"):
            self.execute()
        self.assertFalse(any("/usr/bin/sudo" in c for c in self.apple.calls))

    def test_missing_runtime_requires_explicit_download(self):
        self.apple.data["runtimes"] = []
        with self.assertRaisesRegex(setup.SetupError, "No registered native"):
            self.execute()
        self.assertFalse(any("-downloadPlatform" in c for c in self.apple.calls))

    def test_explicit_download_and_registration(self):
        self.apple.data["runtimes"] = []
        self.args.download_runtime = True
        self.execute()
        download = next(c for c in self.apple.calls if "-downloadPlatform" in c)
        self.assertEqual(
            download[-4:], ("-buildVersion", "27.0", "-architectureVariant", "arm64")
        )

    def test_download_failure_has_diagnostics(self):
        self.apple.data["runtimes"] = []
        self.args.download_runtime = True
        self.apple.download_failure = True
        with self.assertRaisesRegex(setup.SetupError, "Apple download availability"):
            self.execute()

    def test_download_without_registration_is_not_success(self):
        self.apple.data["runtimes"] = []
        self.args.download_runtime = True
        self.apple.download_registers = False
        with self.assertRaisesRegex(setup.SetupError, "No registered native"):
            self.execute()

    def test_device_without_registration_is_not_success(self):
        self.apple.create_registers = False
        with self.assertRaisesRegex(setup.SetupError, "registration not confirmed"):
            self.execute()

    def test_selection_failure_stops_before_first_launch(self):
        self.apple.selection_works = False
        with self.assertRaisesRegex(setup.SetupError, "selection not confirmed"):
            self.execute()
        self.assertFalse(any("-runFirstLaunch" in c for c in self.apple.calls))

    def test_intel_runtime_is_not_reused(self):
        self.apple.runtime_arch = "x86_64"
        with self.assertRaisesRegex(setup.SetupError, "No registered native"):
            self.execute()

    def test_unavailable_or_newer_or_partial_runtime_is_not_reused(self):
        for change in [
            {"isAvailable": False},
            {"version": "28.0"},
            {"supportedDeviceTypes": RUNTIME["supportedDeviceTypes"][:1]},
        ]:
            with self.subTest(change=change):
                self.apple.data["runtimes"] = [dict(RUNTIME, **change)]
                with self.assertRaisesRegex(setup.SetupError, "No registered native"):
                    self.execute()

    def test_exact_runtime_selection_never_downloads_a_substitute(self):
        self.args.runtime = "missing-runtime"
        self.args.download_runtime = True
        with self.assertRaisesRegex(setup.SetupError, "selects an installed runtime"):
            self.execute()
        self.assertFalse(any("-downloadPlatform" in c for c in self.apple.calls))

    def test_rosetta_and_root_are_refused(self):
        self.apple.arch = "x86_64"
        with self.assertRaisesRegex(setup.SetupError, "native Apple Silicon"):
            self.execute()
        self.apple.arch = "arm64"
        with patch.object(setup.os, "geteuid", return_value=0):
            with self.assertRaisesRegex(setup.SetupError, "without sudo"):
                self.execute()

    def test_main_refuses_concurrent_setup(self):
        lock_path = Path(self.temp.name) / "Library/Caches/astraeus-dev-setup.lock"
        lock_path.parent.mkdir(parents=True)
        with lock_path.open("a") as lock:
            setup.fcntl.flock(lock, setup.fcntl.LOCK_EX | setup.fcntl.LOCK_NB)
            with patch.object(setup.Path, "home", return_value=Path(self.temp.name)):
                with patch.object(setup.sys, "argv", ["astraeus-dev-setup"]):
                    with contextlib.redirect_stderr(self.output):
                        with self.assertRaises(SystemExit) as error:
                            setup.main()
        self.assertEqual(error.exception.code, 1)
        self.assertIn("Another astraeus-dev-setup", self.output.getvalue())
        self.assertEqual(self.apple.calls, [])

    def test_main_refuses_linux_before_filesystem_or_apple_work(self):
        with patch.object(setup.sys, "platform", "linux"):
            with patch.object(setup.sys, "argv", ["astraeus-dev-setup"]):
                with patch.object(setup.Path, "home") as home:
                    with contextlib.redirect_stderr(self.output):
                        with self.assertRaises(SystemExit) as error:
                            setup.main()
                    home.assert_not_called()
        self.assertEqual(error.exception.code, 1)
        self.assertEqual(self.apple.calls, [])

    def test_runtime_image_identity_readiness_signature_and_native_arch_are_required(
        self,
    ):
        self.assertTrue(setup.native_runtime(RUNTIME, [RUNTIME_IMAGE]))
        for change in [
            {"runtimeIdentifier": "other-runtime"},
            {"runtimeBundlePath": "/other/iOS.simruntime"},
            {"state": "Installing"},
            {"signatureState": "Other Signature Error"},
            {"supportedArchitectures": ["x86_64"]},
            {"supportedArchitectures": []},
        ]:
            with self.subTest(change=change):
                self.assertFalse(
                    setup.native_runtime(RUNTIME, [dict(RUNTIME_IMAGE, **change)])
                )
        self.assertFalse(
            setup.native_runtime({"identifier": RUNTIME["identifier"]}, [RUNTIME_IMAGE])
        )
        self.assertFalse(setup.native_runtime(RUNTIME, []))

    def test_failed_device_readback_does_not_duplicate_unavailable_registration(self):
        self.apple.registration_available = False
        with self.assertRaisesRegex(setup.SetupError, "registration not confirmed"):
            self.execute()
        for _ in range(2):
            with self.assertRaisesRegex(setup.SetupError, "already exists"):
                self.execute()
        self.assertEqual(sum("create" in c for c in self.apple.calls), 1)

    def test_long_running_apple_commands_stream_progress(self):
        self.apple.data["runtimes"] = []
        self.args.download_runtime = True
        self.execute()
        self.assertTrue(any("--switch" in c for c in self.apple.streamed))
        self.assertTrue(any("-runFirstLaunch" in c for c in self.apple.streamed))
        self.assertTrue(any("-downloadPlatform" in c for c in self.apple.streamed))

    def test_accepted_app_path_override_still_verifies_global_selection(self):
        os.environ["DEVELOPER_DIR"] = str(self.app)
        self.execute()
        self.assertEqual(self.apple.selected, self.apple.developer)

    def test_invalid_apple_json_is_actionable(self):
        with patch.object(
            setup,
            "run",
            return_value=subprocess.CompletedProcess([], 0, "not JSON", ""),
        ):
            with self.assertRaisesRegex(setup.SetupError, "invalid JSON"):
                setup.inventory()

    def test_missing_xcode_is_actionable(self):
        self.args.xcode = "/missing/Xcode.app"
        with self.assertRaisesRegex(setup.SetupError, "Finish the MAS install"):
            self.execute()


if __name__ == "__main__":
    unittest.main()
