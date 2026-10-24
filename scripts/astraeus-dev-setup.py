#!/usr/bin/env python3
"""Explicit Apple Silicon setup; Apple owns Xcode, runtime and device state."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


class SetupError(RuntimeError):
    pass


def run(*args, check=True):
    result = subprocess.run(args, text=True, capture_output=True)
    if check and result.returncode:
        raise SetupError(
            f"{shlex.join(map(str, args))} failed ({result.returncode}):\n"
            f"{result.stdout}{result.stderr}"
        )
    return result


def version(value):
    return tuple(int(n) for n in re.findall(r"\d+", value))


def inventory():
    try:
        return json.loads(run("/usr/bin/xcrun", "simctl", "list", "--json").stdout)
    except json.JSONDecodeError as error:
        raise SetupError(
            "simctl returned invalid JSON; inspect Xcode/CoreSimulator status."
        ) from error


def native_runtime(runtime):
    root = runtime.get("runtimeRoot")
    if not root and runtime.get("bundlePath"):
        root = str(Path(runtime["bundlePath"]) / "Contents/Resources/RuntimeRoot")
    if not root:
        return False
    # Inspect the registered runtime itself; an SDK or downloaded image is not registration.
    for loader in ("dyld_sim", "dyld"):
        result = run(
            "/usr/bin/lipo", "-archs", str(Path(root) / "usr/lib" / loader), check=False
        )
        if result.returncode == 0 and {"arm64", "arm64e"} & set(result.stdout.split()):
            return True
    return False


def choose_runtime(data, sdk_version, requested=None):
    candidates = []
    for runtime in data.get("runtimes", []):
        if not runtime["identifier"].startswith(
            "com.apple.CoreSimulator.SimRuntime.iOS-"
        ):
            continue
        if requested and runtime["identifier"] != requested:
            continue
        if not runtime.get("isAvailable"):
            continue
        if not (version("26.0") <= version(runtime["version"]) <= version(sdk_version)):
            continue
        # Use the runtime's supported types, not the newest global device type.
        types = runtime.get("supportedDeviceTypes", [])
        phone = next((t for t in types if t.get("productFamily") == "iPhone"), None)
        tablet = next((t for t in types if t.get("productFamily") == "iPad"), None)
        if phone and tablet and native_runtime(runtime):
            candidates.append((runtime, phone, tablet))
    return max(candidates, key=lambda item: version(item[0]["version"]), default=None)


def ensure_device(runtime, device_type, family):
    runtime_id = runtime["identifier"]
    devices = inventory().get("devices", {}).get(runtime_id, [])
    # Reuse any available matching family; do not alter its name, boot state or data.
    compatible = {
        t["identifier"]
        for t in runtime["supportedDeviceTypes"]
        if t.get("productFamily") == family
    }
    existing = sorted(
        (
            d
            for d in devices
            if d.get("isAvailable") and d.get("deviceTypeIdentifier") in compatible
        ),
        key=lambda d: d["udid"],
    )
    if existing:
        device_id = existing[0]["udid"]
    else:
        name = f"Astraeus {family} iOS {runtime['version']}"
        device_id = run(
            "/usr/bin/xcrun",
            "simctl",
            "create",
            name,
            device_type["identifier"],
            runtime_id,
        ).stdout.strip()
    registered = inventory().get("devices", {}).get(runtime_id, [])
    if not any(
        d.get("udid") == device_id
        and d.get("isAvailable")
        and d.get("deviceTypeIdentifier") in compatible
        for d in registered
    ):
        raise SetupError(
            f"{family} registration not confirmed: {device_id}. No devices were removed."
        )
    print(f"{family}: {device_id} (iOS {runtime['version']})")
    return device_id


def selected_xcode():
    # xcode-select honors DEVELOPER_DIR; query the system selection without it.
    saved = os.environ.pop("DEVELOPER_DIR", None)
    try:
        return run("/usr/bin/xcode-select", "-p", check=False)
    finally:
        if saved is not None:
            os.environ["DEVELOPER_DIR"] = saved


def setup(args):
    if (
        sys.platform != "darwin"
        or run("/usr/bin/uname", "-m").stdout.strip() != "arm64"
    ):
        raise SetupError(
            "Run on Astraeus in a native Apple Silicon terminal, outside Rosetta."
        )
    if os.geteuid() == 0:
        raise SetupError(
            "Run as your normal Mac user, without sudo; only system setup uses sudo."
        )
    developer = Path(args.xcode).expanduser().resolve() / "Contents/Developer"
    build = str(developer / "usr/bin/xcodebuild")
    if not Path(build).is_file():
        raise SetupError(
            f"Xcode is not installed at {args.xcode}. Finish the MAS install first."
        )
    os.environ["DEVELOPER_DIR"] = str(developer)
    # Check BEFORE runFirstLaunch: never accept a license on the user's behalf.
    if run(build, "-license", "check", check=False).returncode:
        raise SetupError(
            f"License not accepted. Open {args.xcode}, review and accept Apple's terms, "
            "then rerun this command. No license was accepted by this helper."
        )
    selected = selected_xcode()
    if selected.returncode or Path(selected.stdout.strip()).resolve() != developer:
        run("/usr/bin/sudo", "/usr/bin/xcode-select", "--switch", str(developer))
    selected = selected_xcode()
    if selected.returncode or Path(selected.stdout.strip()).resolve() != developer:
        raise SetupError(
            f"Global Xcode selection not confirmed: {selected.stdout}{selected.stderr}"
        )
    if run(build, "-checkFirstLaunchStatus", check=False).returncode:
        run("/usr/bin/sudo", build, "-runFirstLaunch")
        run(build, "-checkFirstLaunchStatus")
    print(run(build, "-version").stdout.strip())
    sdk_version = run(
        build, "-version", "-sdk", "iphonesimulator", "SDKVersion"
    ).stdout.strip()
    data = inventory()
    chosen = choose_runtime(data, sdk_version, args.runtime)
    if not chosen and args.download_runtime:
        if args.runtime:
            raise SetupError(
                "--runtime selects an installed runtime. Omit it to download the SDK runtime."
            )
        print(
            f"Downloading iOS {sdk_version} arm64 runtime through Apple (may take several GB).",
            flush=True,
        )
        try:
            run(
                build,
                "-downloadPlatform",
                "iOS",
                "-buildVersion",
                sdk_version,
                "-architectureVariant",
                "arm64",
            )
        except SetupError as error:
            raise SetupError(
                f"{error}\nCheck free disk space, Apple download availability, network access and "
                "Xcode account prompts. Retry this command or use Xcode Settings > Components. "
                "No caches or devices were deleted."
            ) from error
        chosen = choose_runtime(inventory(), sdk_version)
    if not chosen:
        raise SetupError(
            "No registered native iOS 26+ runtime compatible with this SDK and both iPhone/iPad "
            "was found. Inspect `xcrun simctl list --json` and runtime dyld architecture with lipo. "
            "Rerun with --download-runtime for an explicit Apple download, or install a compatible "
            "runtime in Xcode Settings > Components. Download completion alone is not registration."
        )
    runtime, phone, tablet = chosen
    print(f"Registered runtime: {runtime['identifier']}")
    ensure_device(runtime, phone, "iPhone")
    ensure_device(runtime, tablet, "iPad")
    print(
        "Ready for project-specific builds. Devices were not booted; signing/pairing remain optional."
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--xcode", default="/Applications/Xcode.app", help="installed Xcode app path"
    )
    parser.add_argument(
        "--download-runtime",
        action="store_true",
        help="download only if no compatible runtime exists",
    )
    parser.add_argument(
        "--runtime", help="reuse this exact registered CoreSimulator runtime identifier"
    )
    args = parser.parse_args()
    # Refuse Linux before creating even the lock directory.
    if sys.platform != "darwin":
        parser.exit(1, "error: this setup command runs only on macOS.\n")
    lock_path = Path.home() / "Library/Caches/astraeus-dev-setup.lock"
    try:
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise SetupError(
                    "Another astraeus-dev-setup command is running; wait for it to finish."
                ) from error
            setup(args)
    except (SetupError, OSError) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
