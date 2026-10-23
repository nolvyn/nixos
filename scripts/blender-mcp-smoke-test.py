#!/usr/bin/env python3
"""Exercise the built integration in disposable user directories, without activation.

Requires a graphical session and a free localhost:9876. Leaves logs and renders
in the printed /tmp directory. Never opens or changes the user's scene/preferences.
"""

import argparse
import base64
import json
import os
from pathlib import Path
import queue
import shutil
import socket
import subprocess
import tempfile
import threading
import time


class Rpc:
    def __init__(self, command, env, cwd, log):
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=log,
            text=True,
            env=env,
            cwd=cwd,
            start_new_session=True,
        )
        self.messages = queue.Queue()
        self.counter = 0
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.process.stdout:
            self.messages.put(json.loads(line))

    def send(self, message):
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def call(self, method, params, timeout=60):
        self.counter += 1
        request_id = self.counter
        self.send(
            {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
        )
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            message = self.messages.get(timeout=max(0.1, deadline - time.monotonic()))
            if message.get("id") == request_id and "method" not in message:
                if "error" in message:
                    raise RuntimeError(f"{method}: {message['error']}")
                return message["result"]
            if "id" in message and "method" in message:
                # No consent prompts, approvals, or remote activity are expected.
                raise RuntimeError(f"Unexpected client request: {message}")
        raise TimeoutError(method)

    def close(self):
        import signal

        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGTERM)
            self.process.wait(timeout=10)


def socket_call(kind, **params):
    with socket.create_connection(("127.0.0.1", 9876), timeout=180) as sock:
        sock.sendall(json.dumps({"type": kind, "params": params}).encode())
        data = b""
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                raise ConnectionError("Blender closed the socket before replying")
            data += chunk
            try:
                response = json.loads(data)
                assert response["status"] == "success", response
                return response["result"]
            except json.JSONDecodeError:
                pass


def wait_blender(process):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        assert process.poll() is None, "Blender exited; see blender.log"
        try:
            with socket.create_connection(("127.0.0.1", 9876), timeout=0.2):
                return
        except OSError:
            time.sleep(0.2)
    raise TimeoutError("Blender add-on did not start automatically")


def startup_cases(args, root, base_env, scene_file):
    """Exercise failure paths without touching the real profile or store files."""
    for case in (
        "pending-file-load",
        "collision",
        "loaded-collision",
        "enabled-collision",
        "import-failure",
        "save-failure",
        "custom-profile",
    ):
        directory = root / case
        directory.mkdir()
        env = base_env | {
            "HOME": str(directory),
            "BLENDER_USER_CONFIG": str(directory / "config"),
            "BLENDER_USER_SCRIPTS": str(directory / "scripts"),
            "XDG_CONFIG_HOME": str(directory / ".config"),
            "XDG_DATA_HOME": str(directory / ".local/share"),
        }
        script = directory / "inject.py"
        code = ""
        expected = ""
        shadow = directory / "scripts/addons/blender_mcp.py"
        if "collision" in case:
            shadow.parent.mkdir(parents=True)
            shadow.write_text(
                "# Disposable conflicting user add-on\nVALUE = 'USER_ADDON_UNCHANGED'\n"
                "bl_info = {'name': 'Collision fixture', 'version': (1, 0), 'blender': (3, 0, 0), 'category': 'Interface'}\n"
                "def register(): pass\ndef unregister(): pass\n"
            )
            before = shadow.read_bytes()
            if case == "loaded-collision":
                code = "import blender_mcp\n"
            elif case == "enabled-collision":
                subprocess.run(
                    [
                        args.blender,
                        "--background",
                        "--python-exit-code",
                        "1",
                        "--python-expr",
                        "import addon_utils, bpy; assert addon_utils.enable('blender_mcp', default_set=True); bpy.ops.wm.save_userpref()",
                    ],
                    env=env,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.STDOUT,
                    check=True,
                    timeout=45,
                )
                saved_preferences = (directory / "config/userpref.blend").read_bytes()
            expected = "Conflicting or missing blender_mcp add-on"
        elif case == "pending-file-load":
            code = f"""import bpy, nixos_blender_mcp
assert bpy.app.timers.is_registered(nixos_blender_mcp._enable)
bpy.ops.wm.open_mainfile(filepath={str(scene_file)!r})
assert bpy.app.timers.is_registered(nixos_blender_mcp._enable)
print('PENDING_TIMER_SURVIVED_FILE_LOAD', flush=True)
"""
        elif case == "import-failure":
            code = """import builtins
original_import = builtins.__import__
def fail_requests(name, *args, **kwargs):
    if name == 'requests':
        raise ImportError('TEST injected requests import failure')
    return original_import(name, *args, **kwargs)
builtins.__import__ = fail_requests
"""
            expected = "TEST injected requests import failure"
        elif case == "save-failure":
            code = """import bpy
original_ops = bpy.ops
class WMProxy:
    def __getattr__(self, name):
        if name == 'save_userpref':
            def fail_save():
                raise PermissionError('TEST injected preference-save failure')
            return fail_save
        return getattr(original_ops.wm, name)
class OpsProxy:
    def __getattr__(self, name):
        return WMProxy() if name == 'wm' else getattr(original_ops, name)
bpy.ops = OpsProxy()
"""
            expected = "TEST injected preference-save failure"
        else:
            subprocess.run(
                [
                    args.blender,
                    "--background",
                    "--factory-startup",
                    "--python-exit-code",
                    "1",
                    "--python-expr",
                    "import bpy; assert 'blender_mcp' not in bpy.context.preferences.addons; bpy.context.preferences.view.show_tooltips=False; bpy.context.preferences.filepaths.save_version=3; bpy.context.preferences.inputs.use_emulate_numpad=True; bpy.ops.wm.save_userpref()",
                ],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.STDOUT,
                check=True,
                timeout=45,
            )
        script.write_text(code)
        log_path = directory / "blender.log"
        with log_path.open("w") as log:
            process = subprocess.Popen(
                [args.blender, str(scene_file), "-noaudio", "--python", str(script)],
                env=env,
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            try:
                if case in ("custom-profile", "pending-file-load"):
                    wait_blender(process)
                    if case == "custom-profile":
                        socket_call(
                            "execute_code",
                            code="import bpy; assert not bpy.context.preferences.view.show_tooltips; assert bpy.context.preferences.filepaths.save_version == 3; assert bpy.context.preferences.inputs.use_emulate_numpad",
                        )
                    else:
                        assert (
                            "PENDING_TIMER_SURVIVED_FILE_LOAD" in log_path.read_text()
                        )
                        socket_call(
                            "execute_code",
                            code="import bpy, nixos_blender_mcp; assert not bpy.app.timers.is_registered(nixos_blender_mcp._enable)",
                        )
                    assert (directory / "config/userpref.blend").is_file()
                else:
                    deadline = time.monotonic() + 30
                    while (
                        expected not in log_path.read_text()
                        or "BlenderMCP startup ERROR" not in log_path.read_text()
                    ):
                        assert process.poll() is None, log_path.read_text()
                        if time.monotonic() >= deadline:
                            raise TimeoutError(
                                f"Missing {case} diagnostic: {log_path.read_text()}"
                            )
                        time.sleep(0.1)
                    assert "Nix-managed add-on ready" not in log_path.read_text()
                    if case == "enabled-collision":
                        assert (
                            directory / "config/userpref.blend"
                        ).read_bytes() == saved_preferences
                    else:
                        assert not (directory / "config/userpref.blend").exists()
                    if "collision" in case:
                        assert str(shadow) in log_path.read_text()
                        assert (
                            "expected pinned source /nix/store/" in log_path.read_text()
                        )
                        assert shadow.read_bytes() == before
                print(f"PASS: isolated startup scenario {case}", flush=True)
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)


def cache_cases(args, root, base_env):
    """Simulate link updates/removal and run the generated collision guard."""
    import hashlib

    directory = root / "cache-lifecycle"
    cache = directory / ".codex/plugins/cache/home-manager/mcp-for-blender"
    cache.parent.mkdir(parents=True)
    env = base_env | {"HOME": str(directory), "CODEX_HOME": str(directory / ".codex")}
    marketplace = directory / ".agents/plugins/marketplace.json"
    marketplace.parent.mkdir(parents=True)
    original = json.loads(
        (Path(args.home_files) / ".agents/plugins/marketplace.json").read_text()
    )
    # Materialize the actual five existing plugins in this disposable profile;
    # only list their inventory, never launch their MCP servers or use accounts.
    other_names = []
    for entry in original["plugins"]:
        if entry["name"] == "mcp-for-blender":
            continue
        relative = entry["source"]["path"].removeprefix("./")
        source = Path(args.home_files) / relative
        shutil.copytree(source, directory / relative, symlinks=False)
        other_names.append(entry["name"])
    settings = "[features]\nplugins=true\n" + "".join(
        f'[plugins."{n}@home-manager"]\nenabled=true\n' for n in other_names
    )
    config_path = directory / ".codex/config.toml"
    config_path.write_text(
        settings + '[plugins."mcp-for-blender@home-manager"]\nenabled=true\n'
    )
    marketplace.write_text(json.dumps(original))
    other_files = {
        p: hashlib.sha256(p.read_bytes()).digest()
        for name in other_names
        for p in (cache.parent / name).rglob("*")
        if p.is_file()
    }

    # Replay only these generated blocks, never the full activation. The guard
    # must precede HM's destructive cleanup as well as the write boundary.
    activation = Path(args.activation).read_text()
    positions = {
        name: activation.index(f'_iNote "Activating %s" "{name}"\n')
        for name in (
            "checkBlenderPluginCache",
            "cleanCodexPluginCache",
            "writeBoundary",
        )
    }
    assert positions["checkBlenderPluginCache"] < positions["cleanCodexPluginCache"]
    assert positions["checkBlenderPluginCache"] < positions["writeBoundary"]

    def activation_step(name):
        return activation.split(f'_iNote "Activating %s" "{name}"\n', 1)[1].split(
            "\n_iNote ", 1
        )[0]

    guard = activation_step("checkBlenderPluginCache")
    guard = guard.replace(str(Path.home()), str(directory))
    cleanup = activation_step("cleanCodexPluginCache")
    assert "mcp-for-blender/2.1.1" in cleanup
    print("PASS: generated guard precedes Codex cleanup and writeBoundary", flush=True)

    # A real version directory is precisely what HM's cleanup would remove.
    cache.mkdir()
    sentinel = cache / "user-owned.txt"
    sentinel.write_text("PRESERVE USER CONTENT\n")
    legacy = cache / "2.1.1"
    (legacy / "nested").mkdir(parents=True)
    (legacy / "sentinel.txt").write_text("PRESERVE REAL VERSION\n")
    (legacy / "nested/sentinel.bin").write_bytes(bytes(range(256)))

    def legacy_snapshot(base):
        return {
            str(p.relative_to(base)): (
                p.stat().st_mode,
                p.stat().st_mtime_ns,
                p.read_bytes() if p.is_file() else None,
            )
            for p in [base, *base.rglob("*")]
        }

    before_legacy = legacy_snapshot(cache)
    blocks = {"checkBlenderPluginCache": guard, "cleanCodexPluginCache": cleanup}
    replay = "\n".join(
        f"echo STEP:{name}\n{blocks[name]}"
        for name in sorted(blocks, key=positions.__getitem__)
    )
    refused = subprocess.run(
        ["bash", "-euc", replay], env=env, capture_output=True, text=True
    )
    assert refused.returncode != 0 and "refusing to replace" in refused.stderr, refused
    assert "STEP:checkBlenderPluginCache" in refused.stdout
    assert "STEP:cleanCodexPluginCache" not in refused.stdout
    assert legacy_snapshot(cache) == before_legacy
    print(
        "PASS: refused legacy-cache activation never reaches cleanup; real 2.1.1 sentinels, modes and mtimes unchanged",
        flush=True,
    )
    cache.rename(directory / "legacy-cache-preserved")
    cache.symlink_to(directory / "missing-user-target", target_is_directory=True)
    refused = subprocess.run(
        ["bash", "-euc", guard], env=env, capture_output=True, text=True
    )
    assert refused.returncode != 0 and "dangling cache link" in refused.stderr, refused
    assert cache.readlink() == directory / "missing-user-target"
    cache.rename(directory / "dangling-user-link-preserved")

    current = Path(args.plugin_cache).resolve()
    upgrade = directory / "upgrade-fixture"
    shutil.copytree(current / "default", upgrade / "default", symlinks=False)
    manifest = upgrade / "default/.codex-plugin/plugin.json"
    manifest.chmod(0o644)
    metadata = json.loads(manifest.read_text())
    metadata["version"] = "9.9.9"
    manifest.write_text(json.dumps(metadata))
    (upgrade / "9.9.9").symlink_to("default")
    # Even a simulated stale higher version must lose to Codex's default slot.
    shutil.copytree(upgrade / "default", upgrade / "99.0.0", symlinks=False)

    for label, source, version in [
        ("install", current, "2.1.1"),
        ("upgrade", upgrade, "9.9.9"),
        ("rollback", current, "2.1.1"),
    ]:
        staged = directory / "next-cache-link"
        staged.symlink_to(source, target_is_directory=True)
        os.replace(staged, cache)
        # The upstream cleanup addresses the version alias, which must remain
        # a symlink so it never removes a real directory inside the store.
        assert (cache / version).is_symlink()
        state = json.loads(
            subprocess.check_output(
                [args.codex, "plugin", "list", "--json"],
                env=env,
                cwd=directory,
                text=True,
            )
        )
        installed = {p["name"]: p for p in state["installed"]}
        assert set(installed) == set(other_names) | {"mcp-for-blender"}, state
        assert installed["mcp-for-blender"]["version"] == "default", state
        assert (
            json.loads((cache / "default/.codex-plugin/plugin.json").read_text())[
                "version"
            ]
            == version
        )
        print(
            f"PASS: Codex plugin {label} selects default/{version}; existing plugins still discovered",
            flush=True,
        )
    # Exercise HM's actual generated leaf link/cleanup scripts in this HOME.
    # No full activation or user service is run. Only our test-owned cache link
    # is removed; the five unrelated plugin trees must remain byte-for-byte.
    import re

    link_script = re.search(
        r'-exec bash (/nix/store/\S+-link) "\$newGenFiles"', activation
    )[1]
    cleanup_script = re.search(
        r'xargs -0 bash (/nix/store/\S+-cleanup) "\$newGenFiles"', activation
    )[1]
    relative = ".codex/plugins/cache/home-manager/mcp-for-blender"
    subprocess.run(
        ["bash", link_script, args.home_files, str(Path(args.home_files) / relative)],
        env=env,
        check=True,
    )
    assert cache.is_symlink()
    empty_generation = directory / "generation-without-blender"
    empty_generation.mkdir()
    subprocess.run(
        ["bash", cleanup_script, str(empty_generation), relative], env=env, check=True
    )
    assert not cache.exists() and not cache.is_symlink()
    config_path.write_text(settings)
    removed = json.loads(json.dumps(original))
    removed["plugins"] = [
        p for p in removed["plugins"] if p["name"] != "mcp-for-blender"
    ]
    marketplace.write_text(json.dumps(removed))
    state = json.loads(
        subprocess.check_output(
            [args.codex, "plugin", "list", "--json"], env=env, cwd=directory, text=True
        )
    )
    assert {p["name"] for p in state["installed"]} == set(other_names), state
    assert all(
        hashlib.sha256(p.read_bytes()).digest() == digest
        for p, digest in other_files.items()
    )
    assert (
        directory / "legacy-cache-preserved/user-owned.txt"
    ).read_text() == "PRESERVE USER CONTENT\n"
    assert legacy_snapshot(directory / "legacy-cache-preserved") == before_legacy
    print(
        "PASS: simulated aspect removal removes Blender discovery; legacy/user files and other plugins unchanged",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blender", required=True)
    parser.add_argument("--home-files", required=True)
    parser.add_argument("--plugin", required=True)
    parser.add_argument("--plugin-cache", required=True)
    parser.add_argument("--activation", required=True)
    parser.add_argument("--codex", default="codex")
    args = parser.parse_args()
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 9876))
    root = Path(tempfile.mkdtemp(prefix="blender-mcp-test-"))
    print(f"Artifacts: {root}", flush=True)
    env = os.environ | {
        "HOME": str(root),
        "CODEX_HOME": str(root / ".codex"),
        "XDG_CONFIG_HOME": str(root / ".config"),
        "XDG_DATA_HOME": str(root / ".local/share"),
        "BLENDER_USER_CONFIG": str(root / "blender-config"),
        "BLENDER_USER_SCRIPTS": str(root / "blender-scripts"),
        "WAYLAND_DISPLAY": os.environ.get("WAYLAND_DISPLAY", "wayland-1"),
    }
    home_files = Path(args.home_files)
    # Match HM's cache-root link; versions/manifests inside it remain regular.
    plugin = Path(args.plugin)
    version = json.loads((plugin / ".codex-plugin/plugin.json").read_text())["version"]
    cache = root / ".codex/plugins/cache/home-manager/mcp-for-blender"
    cache.parent.mkdir(parents=True)
    cache.symlink_to(Path(args.plugin_cache).resolve(), target_is_directory=True)
    assert (cache / version).is_symlink()
    assert not (cache / "default/.codex-plugin/plugin.json").is_symlink()
    (root / ".agents/plugins").mkdir(parents=True)
    shutil.copyfile(
        home_files / ".agents/plugins/marketplace.json",
        root / ".agents/plugins/marketplace.json",
    )
    # Use the exact generated Blender plugin registration in an isolated Codex
    # instance; unrelated plugins and MCP services need not start for this test.
    (root / ".codex/config.toml").write_text(
        '[features]\nplugins = true\n[plugins."mcp-for-blender@home-manager"]\nenabled = true\n'
    )
    blender_log = (root / "blender.log").open("w")
    blender = None
    codex = None
    try:
        scene_file = root / "existing.blend"
        subprocess.run(
            [
                args.blender,
                "--background",
                "--factory-startup",
                "--python-exit-code",
                "1",
                "--python-expr",
                f"import bpy; bpy.ops.wm.save_as_mainfile(filepath={str(scene_file)!r})",
            ],
            env=env,
            stdout=blender_log,
            stderr=subprocess.STDOUT,
            check=True,
            timeout=45,
        )
        assert not (root / "blender-config/userpref.blend").exists()
        blender = subprocess.Popen(
            [args.blender, str(scene_file), "-noaudio"],
            env=env,
            stdout=blender_log,
            stderr=subprocess.STDOUT,
        )
        wait_blender(blender)
        print(
            "PASS: GUI launch, requests import, declarative enablement, automatic socket startup",
            flush=True,
        )
        info = socket_call("get_addon_info")
        socket_call(
            "execute_code",
            code=f"import bpy, blender_mcp, nixos_blender_mcp\nfrom pathlib import Path\nassert bpy.data.filepath == {str(scene_file)!r}\nassert Path(blender_mcp.__file__).resolve() == nixos_blender_mcp.EXPECTED_ADDON",
        )
        print(
            "PASS: first GUI launch directly opens an existing .blend and loads the pinned add-on",
            flush=True,
        )
        (root / "addon-info.json").write_text(json.dumps(info, indent=2))
        assert socket_call("get_telemetry_consent")["consent"] is False
        socket_call(
            "execute_code",
            code="import bpy\nbpy.context.preferences.view.show_splash = False\nbpy.context.preferences.view.show_tooltips = False\nbpy.ops.wm.save_userpref()",
        )
        preferences = root / "blender-config/userpref.blend"
        assert preferences.is_file() and not preferences.is_symlink()
        # Reload the saved preferences in a fresh GUI process, with no bootstrap
        # changes expected. This also catches startup/add-on double registration.
        blender.terminate()
        blender.wait(timeout=15)
        previous = preferences.read_bytes()
        blender = subprocess.Popen(
            [args.blender, str(scene_file), "-noaudio"],
            env=env,
            stdout=blender_log,
            stderr=subprocess.STDOUT,
        )
        wait_blender(blender)
        # Let upstream's five-second update timer run before asserting privacy.
        time.sleep(5.2)
        result = socket_call(
            "execute_code",
            code="import bpy\nassert bpy.context.preferences.view.show_tooltips is False\nprint('PREFERENCE_PERSISTENCE_OK')",
        )
        assert "PREFERENCE_PERSISTENCE_OK" in json.dumps(result), result
        assert preferences.read_bytes() == previous, (
            "Startup unexpectedly rewrote preferences"
        )
        print(
            "PASS: mutable preferences survive restart; idempotent add-on startup",
            flush=True,
        )
        socket_call(
            "execute_code",
            code="import os, blender_mcp, bpy\nassert os.environ['BLENDERMCP_NO_UPDATE_CHECK'] == '1'\nassert blender_mcp._addon_update['status'] == 'idle'\nassert not any(getattr(bpy.context.scene, 'blendermcp_use_' + provider) for provider in ('polyhaven', 'hyper3d', 'hunyuan3d', 'sketchfab', 'tripo', 'polypizza'))",
        )
        print(
            "PASS: automatic update check stayed idle; external asset/generation providers disabled",
            flush=True,
        )
        codex = Rpc(
            [args.codex, "app-server", "--stdio"],
            env,
            root,
            (root / "codex.log").open("w"),
        )
        codex.call(
            "initialize",
            {
                "clientInfo": {"name": "blender_nix_test", "version": "1"},
                "capabilities": {"experimentalApi": True},
            },
        )
        codex.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
        thread = codex.call("thread/start", {"cwd": str(root), "ephemeral": True})[
            "thread"
        ]["id"]
        status = codex.call("mcpServerStatus/list", {"threadId": thread})
        (root / "codex-mcp-status.json").write_text(json.dumps(status, indent=2))
        servers = status["data"]
        candidates = [s for s in servers if "blender" in s["name"]]
        assert len(candidates) == 1, candidates
        server = candidates[0]["name"]
        print(f"PASS: Codex discovers exactly one Blender server: {server}", flush=True)

        def tool(name, arguments):
            result = codex.call(
                "mcpServer/tool/call",
                {
                    "threadId": thread,
                    "server": server,
                    "tool": name,
                    "arguments": arguments,
                },
            )
            assert not result.get("isError"), result
            return result

        result = tool(
            "execute_blender_code",
            {
                "code": "import bpy\nbpy.ops.mesh.primitive_cube_add()\nobj = bpy.context.object\nobj.name = 'NixMcpSmokeCube'\nobj.location = (1.0, 2.0, 3.0)\nobj.scale = (1.5, 0.5, 2.0)\nassert obj.location.z == 3.0\nfor area in bpy.context.screen.areas:\n    if area.type == 'VIEW_3D':\n        area.spaces.active.region_3d.view_location = obj.location\nprint('OBJECT_CREATED_AND_MODIFIED')"
            },
        )
        assert "OBJECT_CREATED_AND_MODIFIED" in json.dumps(result), result
        print("PASS: Codex creates and modifies a Blender object", flush=True)
        rejected = tool(
            "execute_blender_code", {"code": "import os\nprint(os.listdir('/'))"}
        )
        assert (
            "safe" in json.dumps(rejected).lower()
            or "blocked" in json.dumps(rejected).lower()
        ), rejected
        print(
            "PASS: upstream script validation rejects raw filesystem access", flush=True
        )
        screenshot = tool("look", {"max_size": 800})
        images = [c for c in screenshot["content"] if c["type"] == "image"]
        assert images, screenshot
        png = base64.b64decode(images[0]["data"])
        assert png.startswith(b"\x89PNG\r\n\x1a\n") and len(png) > 1000
        (root / "viewport.png").write_bytes(png)
        print(f"PASS: Codex retrieves a viewport PNG ({len(png)} bytes)", flush=True)
        capture = tool("viewport_capture", {"max_size": 800})
        (root / "viewport-state.json").write_text(
            json.dumps(capture.get("structuredContent"), indent=2)
        )
        picked = tool(
            "viewport_pick",
            {"seq": capture["structuredContent"]["seq"], "x": 0.5, "y": 0.5},
        )
        assert picked["structuredContent"]["object"]["name"] == "NixMcpSmokeCube", (
            picked
        )
        (root / "picked-object.json").write_text(json.dumps(picked, indent=2))
        mentions = tool("search_mentions", {"query": "NixMcpSmokeCube"})
        assert "NixMcpSmokeCube" in json.dumps(mentions), mentions
        resource = codex.call(
            "mcpServer/resource/read",
            {
                "threadId": thread,
                "server": server,
                "uri": "ui://mcp-for-blender/viewport-v2",
            },
        )
        (root / "viewport-resource.json").write_text(json.dumps(resource, indent=2))
        assert "text/html;profile=mcp-app" in json.dumps(resource), resource
        print(
            "PASS: viewport object picking, scene-object mentions, and MCP Apps HTML resource",
            flush=True,
        )
        # HIP must render, rather than merely enumerate the GPU.
        render = root / "hip.png"
        result = socket_call(
            "execute_code",
            code=f"""import bpy
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'HIP'
prefs.get_devices()
gpu_found = False
for device in prefs.devices:
    device.use = device.type == 'HIP' and '7800' in device.name
    gpu_found = gpu_found or device.use
assert gpu_found, 'RX 7800 XT HIP device not found'
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'GPU'
scene.cycles.samples = 4
scene.render.resolution_x = 64
scene.render.resolution_y = 64
scene.render.resolution_percentage = 100
scene.render.filepath = {str(render)!r}
bpy.ops.render.render(write_still=True)
print('HIP_RENDER_OK')
""",
        )
        assert "HIP_RENDER_OK" in json.dumps(result), result
        assert render.is_file()
        print("PASS: Cycles HIP render on RX 7800 XT (CPU device disabled)", flush=True)
        listeners = subprocess.check_output(["ss", "-ltnp"], text=True)
        relevant = [line for line in listeners.splitlines() if ":9876 " in line]
        assert len(relevant) == 1 and "127.0.0.1:9876" in relevant[0], relevant
        (root / "socket.txt").write_text("\n".join(relevant))
        assert socket_call("get_telemetry_consent")["consent"] is False
        print(
            "PASS: socket bound only to 127.0.0.1; telemetry consent remains false",
            flush=True,
        )
        codex.close()
        codex = None
        blender.terminate()
        blender.wait(timeout=15)
        previous = preferences.read_bytes()
        blender = subprocess.Popen(
            [args.blender, "--factory-startup", "-noaudio"],
            env=env,
            stdout=blender_log,
            stderr=subprocess.STDOUT,
        )
        time.sleep(2)
        assert blender.poll() is None, "Factory-startup Blender exited"
        assert preferences.read_bytes() == previous, (
            "Factory startup overwrote real preferences"
        )
        try:
            with socket.create_connection(("127.0.0.1", 9876), timeout=0.2):
                raise AssertionError("Factory startup unexpectedly enabled Blender MCP")
        except ConnectionRefusedError:
            pass
        print(
            "PASS: --factory-startup preserves user preferences and leaves MCP disabled",
            flush=True,
        )
        blender.terminate()
        blender.wait(timeout=15)
        subprocess.run(
            [
                args.blender,
                "--background",
                str(scene_file),
                "--python-exit-code",
                "1",
                "--python-expr",
                f"import bpy, addon_utils; assert addon_utils.check('blender_mcp')[1]; assert not bpy.context.preferences.view.show_tooltips; bpy.context.scene.render.engine='CYCLES'; bpy.context.scene.cycles.device='CPU'; bpy.context.scene.cycles.samples=1; bpy.context.scene.render.resolution_x=32; bpy.context.scene.render.resolution_y=32; bpy.context.scene.render.filepath={str(root / 'background.png')!r}; bpy.ops.render.render(write_still=True)",
            ],
            env=env,
            stdout=blender_log,
            stderr=subprocess.STDOUT,
            check=True,
            timeout=60,
        )
        assert (root / "background.png").is_file()
        assert preferences.read_bytes() == previous
        print(
            "PASS: background render loads saved add-on/custom preferences without starting MCP or rewriting preferences",
            flush=True,
        )
        startup_cases(args, root, env, scene_file)
        cache_cases(args, root, env)
    finally:
        if codex:
            codex.close()
        if blender and blender.poll() is None:
            blender.terminate()
            blender.wait(timeout=15)
        blender_log.close()


if __name__ == "__main__":
    main()
