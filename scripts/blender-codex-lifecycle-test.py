#!/usr/bin/env python3
"""Disposable Codex/Home Manager lifecycle controls; never activate a user profile."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess

SOURCE = ".local/share/codex-plugins/mcp-for-blender"
LAUNCHER = ".local/share/codex-plugins/blender-mcp-server"
CACHE = ".codex/plugins/cache/home-manager/mcp-for-blender"


def load(name):
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), Path(__file__).with_name(name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def isolated_env(home):
    return {
        "HOME": str(home),
        "CODEX_HOME": str(home / ".codex"),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "PATH": os.environ["PATH"],
        "LANG": "C.UTF-8",
        "__ETC_BASHRC_SOURCED": "1",
        "__ETC_PROFILE_DONE": "1",
        "HOME_MANAGER_BACKUP_EXT": "",
        "HOME_MANAGER_BACKUP_COMMAND": "",
        "HOME_MANAGER_BACKUP_OVERWRITE": "",
    }


def prepare_profile(home, home_files, all_plugins=False):
    """Copy immutable fixture inputs; rewrite only the fixture's home prefix."""
    home.mkdir(parents=True, exist_ok=True)
    files = Path(home_files).resolve()
    metadata = json.loads((files / ".agents/plugins/marketplace.json").read_text())
    entry = next(p for p in metadata["plugins"] if p["name"] == "mcp-for-blender")
    assert entry["source"] == {"source": "local", "path": "./" + SOURCE}
    source = home.parent / (home.name + "-plugin-input")
    shutil.copytree(files / SOURCE, source)
    command = str(home / LAUNCHER)
    config = json.loads((source / ".mcp.json").read_text())
    production_command = config["mcpServers"]["mcp-for-blender"]["command"]
    assert (
        production_command.endswith("/" + LAUNCHER)
        and Path(production_command).is_absolute()
    )
    config["mcpServers"]["mcp-for-blender"]["command"] = command
    (source / ".mcp.json").chmod(0o600)
    (source / ".mcp.json").write_text(json.dumps(config))
    (home / SOURCE).parent.mkdir(parents=True)
    (home / SOURCE).symlink_to(source)
    (home / LAUNCHER).symlink_to((files / LAUNCHER).resolve(strict=True))
    enabled = []
    if all_plugins:
        for plugin in metadata["plugins"]:
            if plugin["name"] == "mcp-for-blender":
                continue
            relative = plugin["source"]["path"].removeprefix("./")
            shutil.copytree(files / relative, home / relative, symlinks=False)
            enabled.append(plugin["name"])
    else:
        metadata["plugins"] = [entry]
    marketplace = home / ".agents/plugins/marketplace.json"
    marketplace.parent.mkdir(parents=True)
    marketplace.write_text(json.dumps(metadata))
    codex = home / ".codex"
    codex.mkdir(exist_ok=True)
    settings = "[features]\nplugins=true\n" + "".join(
        f'[plugins."{name}@home-manager"]\nenabled=true\n'
        for name in enabled + ["mcp-for-blender"]
    )
    (codex / "config.toml").write_text(settings)
    return source, command, metadata, enabled


def snapshot(root):
    result = {}
    for path in [root, *root.rglob("*")]:
        s = path.lstat()
        value = [stat.S_IMODE(s.st_mode), s.st_uid, s.st_gid, s.st_mtime_ns]
        if path.is_symlink():
            value += ["link", os.readlink(path)]
        elif path.is_file():
            value += ["file", hashlib.sha256(path.read_bytes()).hexdigest()]
        else:
            value += ["directory"]
        result[str(path.relative_to(root))] = value
    return result


def run_lifecycle(args, root):
    check = load("blender-codex-source-check")
    migration = load("blender-codex-cache-preserve")
    rpc_class = load("blender-mcp-smoke-test").Rpc
    home = root / "lifecycle-home"
    source, command, metadata, others = prepare_profile(
        home, args.home_files, all_plugins=False
    )
    env = isolated_env(home)
    fixture_generation = root / "fixture-generation"
    fixture_files = fixture_generation / "home-files"
    for relative in [SOURCE, LAUNCHER]:
        leaf = fixture_files / relative
        leaf.parent.mkdir(parents=True, exist_ok=True)
        leaf.symlink_to((home / relative).resolve())
        (home / relative).unlink()
        (home / relative).symlink_to(leaf)
    env["oldGenPath"] = str(fixture_generation)
    passed = []

    def ok(condition, name):
        assert condition, name
        passed.append(name)

    def refuses(fn, name):
        try:
            fn()
        except (ValueError, OSError, KeyError, TypeError):
            passed.append(name)
        else:
            raise AssertionError(name)

    def cli(*words):
        process = subprocess.run(
            [args.codex, "plugin", *words, "--json"],
            env=env,
            cwd=home,
            text=True,
            capture_output=True,
            timeout=20,
        )
        assert process.returncode == 0, process.stderr
        return json.loads(process.stdout)

    def refresh(label):
        with (root / (label + ".log")).open("w") as log:
            rpc = rpc_class(
                [args.codex, "app-server", "--listen", "stdio://"], env, home, log
            )
            try:
                rpc.call(
                    "initialize",
                    {"clientInfo": {"name": "blender-cache-fixture", "version": "2"}},
                )
                for force in [False, True]:
                    result = rpc.call(
                        "plugin/list",
                        {"marketplaceKinds": ["local"], "forceRefetch": force},
                        timeout=20,
                    )
                    assert not result.get("marketplaceLoadErrors"), result
                rpc.call("plugin/installed", {"cwds": []}, timeout=20)
            finally:
                rpc.close()
            assert rpc.process.returncode == 0

    files = Path(args.home_files).resolve()
    activation = Path(args.activation).read_text()

    def step(name):
        return activation.split(f'_iNote "Activating %s" "{name}"\n', 1)[1].split(
            "\n_iNote ", 1
        )[0]

    guard_position = activation.index(
        '_iNote "Activating %s" "checkBlenderPluginCache"'
    )
    ok(
        guard_position < activation.index('_iNote "Activating %s" "writeBoundary"')
        and guard_position
        < activation.index('_iNote "Activating %s" "cleanCodexPluginCache"'),
        "compatibility guard precedes writes/cleanup",
    )
    cleanup = step("cleanCodexPluginCache")
    ok(
        "mcp-for-blender" not in cleanup,
        "Blender mutable cache excluded from HM deletion",
    )
    link = re.search(r'-exec bash (/nix/store/\S+-link) "\$newGenFiles"', activation)[1]
    orphan = re.search(
        r'xargs -0 bash (/nix/store/\S+-cleanup) "\$newGenFiles"', activation
    )[1]
    bash = Path(link).read_text().splitlines()[0][2:]
    cache = home / CACHE
    cache.parent.mkdir(parents=True, exist_ok=True)
    data = home / ".codex/plugins/data/mcp-for-blender-home-manager"
    data.mkdir(parents=True)
    (data / "state").write_bytes(b"USER STATE")
    unrelated = cache.parent / "unrelated-user-plugin"
    unrelated.mkdir()
    (unrelated / "sentinel").write_bytes(b"UNRELATED USER PLUGIN")
    unrelated_before = snapshot(unrelated)
    if getattr(args, "previous_home_files", None):
        old_files = Path(args.previous_home_files).resolve()
        old_metadata = json.loads(
            (old_files / ".agents/plugins/marketplace.json").read_text()
        )
        full_metadata = json.loads(
            (files / ".agents/plugins/marketplace.json").read_text()
        )
        ok(
            [p for p in old_metadata["plugins"] if p["name"] != "mcp-for-blender"]
            == [p for p in full_metadata["plugins"] if p["name"] != "mcp-for-blender"],
            "all unrelated generated plugin entries are identical",
        )
        ok(
            (old_files / ".codex/config.toml").read_bytes()
            == (files / ".codex/config.toml").read_bytes(),
            "generated Codex settings are byte-identical",
        )
    # Prove that an old real cache is refused, then preserved without deleting entries.
    cache.mkdir()
    shutil.copytree(source, cache / "2.1.1", dirs_exist_ok=True)
    (cache / "2.1.1").chmod(0o700)
    old_config = cache / "2.1.1/.mcp.json"
    old_json = json.loads(old_config.read_text())
    old_json["mcpServers"]["mcp-for-blender"]["command"] = (
        "/nix/store/old-server/bin/server"
    )
    old_config.write_text(json.dumps(old_json))
    (cache / "2.1.1/unique-user-file").write_bytes(b"PRESERVE NESTED CACHE DATA")
    previous = snapshot(cache)
    refuses(
        lambda: check.verify_cache(cache, command),
        "old same-version executable path refuses before mutation",
    )
    ok(snapshot(cache) == previous, "refused cache remains exact")
    plan = migration.preserve(home / ".codex")
    ok(
        not plan["applied"] and snapshot(cache) == previous,
        "migration defaults to read-only plan",
    )
    refuses(
        lambda: migration.preserve(home / ".codex", True, False),
        "migration requires explicit quiescent prerequisite",
    )
    preserved = migration.preserve(home / ".codex", True, True)
    backup = Path(preserved["backup"])
    ok(
        snapshot(backup) == previous and not cache.exists(),
        "initial real cache atomically preserved, including unknown contents",
    )
    ok(
        stat.S_IMODE(backup.parent.stat().st_mode) == 0o700,
        "migration backup parent is private",
    )
    check.verify_cache(cache, command)
    cli("add", "mcp-for-blender@home-manager")
    ok(
        cache.is_dir() and not cache.is_symlink(),
        "fresh install creates Codex-owned real cache",
    )
    refresh("refresh")
    cli("add", "mcp-for-blender@home-manager")
    ok(not cache.is_symlink(), "explicit reinstall leaves compatible ownership")
    check.verify_cache(cache, command)
    (cache / "2.1.1/retained-user-file").write_bytes(b"RETAIN THROUGH SERVER REBUILDS")
    (cache / "root-user-file").write_bytes(b"RETAIN ROOT FILE")
    before = snapshot(cache)
    cached = json.loads((cache / "2.1.1/.mcp.json").read_text())
    ok(
        cached["mcpServers"]["mcp-for-blender"]["command"] == command,
        "cached command is stable absolute fixture launcher",
    )
    launcher = fixture_files / LAUNCHER
    executable_a, executable_b = root / "server-a", root / "server-b"
    for path, marker in [(executable_a, "SOURCE_A"), (executable_b, "SOURCE_B")]:
        path.write_text('#!/bin/sh\nprintf "%s\\n" ' + marker + "\n")
        path.chmod(0o555)
    for label, executable, expected in [
        ("baseline", executable_a, "SOURCE_A"),
        ("same-version-update", executable_b, "SOURCE_B"),
        ("same-version-rollback", executable_a, "SOURCE_A"),
    ]:
        launcher.unlink()
        launcher.symlink_to(executable)
        refresh(label)
        output = subprocess.check_output(
            [cached["mcpServers"]["mcp-for-blender"]["command"]],
            env=env,
            text=True,
            timeout=5,
        ).strip()
        ok(output == expected, label + " executes current source")
        ok(
            snapshot(cache) == before,
            label + " leaves cache and nested user contents unchanged",
        )
        check.verify_cache(cache, command)
    for repeat in range(2):
        # Actual generated guard runs against the disposable HOME, not production.
        guard = step("checkBlenderPluginCache").replace("/home/weeb", str(home))
        subprocess.run([bash, "-euc", guard], env=env, cwd=home, check=True)
        subprocess.run([bash, "-euc", cleanup], env=env, cwd=home, check=True)
        ok(
            snapshot(cache) == before,
            "repeat activation guard/cleanup preserves cache " + str(repeat + 1),
        )
    # Packaged-source mutations must fail closed, including new entries and file types.
    check.verify(source, command)
    for index, relative in enumerate(check.RAW):
        mutated = root / ("mutated-file-" + str(index))
        shutil.copytree(source, mutated)
        mutated.chmod(0o700)
        path = mutated / relative
        path.chmod(0o600)
        path.write_bytes(path.read_bytes() + b"X")
        refuses(
            lambda p=mutated: check.verify(p, command),
            "source guard rejects changed " + relative,
        )
    for kind in ["extra-file", "empty-directory", "symlink", "fifo"]:
        mutated = root / kind
        shutil.copytree(source, mutated)
        mutated.chmod(0o700)
        entry = mutated / "unexpected"
        if kind == "extra-file":
            entry.write_bytes(b"NEW")
        elif kind == "empty-directory":
            entry.mkdir()
        elif kind == "symlink":
            entry.symlink_to("/not-a-fixture-target")
        else:
            os.mkfifo(entry)
        refuses(
            lambda p=mutated: check.verify(p, command), "source guard rejects " + kind
        )
    for mutation in [
        "missing-manifest",
        "executable-icon",
        "file-replaced-by-directory",
    ]:
        mutated = root / mutation
        shutil.copytree(source, mutated)
        if mutation == "missing-manifest":
            (mutated / ".codex-plugin").chmod(0o700)
            (mutated / ".codex-plugin/plugin.json").unlink()
        elif mutation == "executable-icon":
            (mutated / "assets/icon.svg").chmod(0o755)
        else:
            mutated.chmod(0o700)
            (mutated / ".mcp.json").unlink()
            (mutated / ".mcp.json").mkdir()
        refuses(
            lambda p=mutated: check.verify(p, command),
            "source guard rejects " + mutation,
        )
    for field, value in [
        ("args", ["--changed"]),
        ("env", {"UNEXPECTED": "1"}),
        ("env_vars", ["UNEXPECTED"]),
        ("tool_timeout_sec", 1),
    ]:
        mutated = root / ("mcp-" + field)
        shutil.copytree(source, mutated)
        mutated.chmod(0o700)
        path = mutated / ".mcp.json"
        path.chmod(0o600)
        config = json.loads(path.read_text())
        config["mcpServers"]["mcp-for-blender"][field] = value
        path.write_text(json.dumps(config))
        refuses(
            lambda p=mutated: check.verify(p, command),
            "source guard rejects changed MCP " + field,
        )
    # New immutable source and launcher must retain upstream collision protection.
    for relative in [SOURCE, LAUNCHER]:
        for kind in ["file", "directory", "dangling-link"]:
            collision_home = root / (
                "collision-" + relative.split("/")[-1] + "-" + kind
            )
            target = collision_home / relative
            target.parent.mkdir(parents=True)
            if kind == "file":
                target.write_bytes(b"USER CONTENT")
            elif kind == "directory":
                target.mkdir()
                (target / "user").write_bytes(b"USER CONTENT")
            else:
                target.symlink_to("/not-a-fixture-target")
            previous_collision = snapshot(target)
            collision_guard = step("checkBlenderPluginCache").replace(
                "/home/weeb", str(collision_home)
            )
            process = subprocess.run(
                [bash, "-euc", collision_guard],
                env=isolated_env(collision_home),
                capture_output=True,
            )
            ok(
                process.returncode != 0 and snapshot(target) == previous_collision,
                "HM refuses/preserves " + relative + " " + kind,
            )
    # Old-layout rollback is explicitly preservation-first, never an automatic overwrite.
    rollback_before = snapshot(cache)
    preserved_rollback = migration.preserve(home / ".codex", True, True)
    ok(
        snapshot(Path(preserved_rollback["backup"])) == rollback_before,
        "old-layout rollback preserves complete real cache",
    )
    if getattr(args, "previous_home_files", None):
        old_files = Path(args.previous_home_files).resolve()
        subprocess.run(
            [bash, link, str(old_files), str(old_files / CACHE)],
            env=env,
            cwd=home,
            check=True,
        )
        ok(
            cache.is_symlink() and os.readlink(cache) == str(old_files / CACHE),
            "old-layout rollback links only after preservation",
        )
        check.verify_cache(cache, command, old_files, CACHE)
        subprocess.run([bash, orphan, str(files), CACHE], env=env, cwd=home, check=True)
        ok(
            not cache.exists() and not cache.is_symlink(),
            "forward transition removes only verified old HM link",
        )
    cli("add", "mcp-for-blender@home-manager")
    removal_before = snapshot(cache)
    # Give links their actual managed-generation identities, then remove only those links.
    for relative in [SOURCE, LAUNCHER]:
        subprocess.run(
            [bash, link, str(files), str(files / relative)],
            env=env,
            cwd=home,
            check=True,
        )
    empty = root / "empty-generation"
    empty.mkdir()
    subprocess.run(
        [bash, orphan, str(empty), SOURCE, LAUNCHER], env=env, cwd=home, check=True
    )
    ok(
        not (home / SOURCE).exists() and not (home / LAUNCHER).exists(),
        "aspect removal cleans only owned immutable links",
    )
    metadata["plugins"] = [
        p for p in metadata["plugins"] if p["name"] != "mcp-for-blender"
    ]
    (home / ".agents/plugins/marketplace.json").write_text(json.dumps(metadata))
    (home / ".codex/config.toml").write_text(
        "[features]\nplugins=true\n"
        + "".join(f'[plugins."{name}@home-manager"]\nenabled=true\n' for name in others)
    )
    ok(
        {p["name"] for p in cli("list")["installed"]} == set(others),
        "aspect removal removes only Blender discovery",
    )
    ok(
        snapshot(cache) == removal_before
        and snapshot(backup) == previous
        and (data / "state").read_bytes() == b"USER STATE",
        "removal preserves cache, backup and separate plugin data",
    )
    ok(snapshot(unrelated) == unrelated_before, "unrelated user plugin remains exact")
    compatibility = load("blender-codex-compat-test").run(
        Path(__file__).parents[1], root / "compatibility"
    )
    for name in compatibility["passed"]:
        passed.append("compatibility anchor " + name)
    result = {
        "passed": passed,
        "groups": len(passed),
        "root": str(root),
        "claims": "isolated source/cache/launcher and generated helper tests; no live activation/GUI qualification",
        "compatibility": compatibility,
    }
    (root / "cache-lifecycle-result.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    print(json.dumps(result, indent=2))
    return result
