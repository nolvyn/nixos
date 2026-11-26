#!/usr/bin/env python3
"""Check pinned Blender plugin inputs and cache compatibility without mutation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat

STORE = Path("/nix/store")

RAW = {
    ".mcp.json": "cc792dbba763503807e8450b23aa69813d4885cbe718493cedb68b7f82bda30f",
    ".codex-plugin/plugin.json": "aef4380b896d6d3d4d81aba593d5e553c937857a4feaad60d8f077bb20a8b20e",
    "assets/icon.svg": "1475c10f2e8f2f515ece7e8eeb126566c38bbfab7dc828c23b2ca9271969925a",
    "assets/logo.png": "9f118ba8a24ca0da58f831e96078af60c8e9f3619841388ab23a99cd88a1cc4e",
}
MCP = "82e066f2325b855350a951952b3a9be76f6acdd378de9f9fcb9aec50b0a65d76"
DIRECTORIES = {".codex-plugin", "assets"}


def verify(root, command=None, allow_extras=False):
    root = Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("plugin source must be a real directory")
    files, directories = set(), set()
    for path in root.rglob("*"):
        relative = str(path.relative_to(root))
        kind = path.lstat().st_mode
        if stat.S_ISREG(kind):
            if kind & 0o111 and (not allow_extras or relative in RAW):
                raise ValueError("plugin metadata/assets unexpectedly executable")
            files.add(relative)
        elif stat.S_ISDIR(kind):
            directories.add(relative)
        else:
            raise ValueError("plugin source contains a link or special entry")
    if not set(RAW) <= files or (
        not allow_extras and (files != set(RAW) or directories != DIRECTORIES)
    ):
        raise ValueError(
            "plugin file inventory changed; review upstream metadata/version"
        )
    for relative, expected in RAW.items():
        path = root / relative
        if relative == ".mcp.json" and command is not None:
            data = json.loads(path.read_text())
            server = data["mcpServers"]["mcp-for-blender"]
            if server["command"] != command:
                raise ValueError(
                    "cached MCP command requires preservation-first migration"
                )
            server["command"] = "<launcher>"
            actual = hashlib.sha256(
                json.dumps(data, sort_keys=True, separators=(",", ":")).encode()
            ).hexdigest()
            expected = MCP
        else:
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(
                "plugin contents changed: "
                + relative
                + "; review upstream metadata/version"
            )


def system_home_files(unit):
    """Authorize only the generation named by the immutable active system unit."""
    unit = Path(unit).resolve(strict=True)
    meta = unit.stat()
    if (
        not unit.is_relative_to(STORE)
        or not stat.S_ISREG(meta.st_mode)
        or meta.st_uid != 0
        or meta.st_mode & 0o222
    ):
        raise ValueError(
            "Home Manager recovery unit must be immutable in the Nix store"
        )
    commands = [
        shlex.split(line.removeprefix("ExecStart="))
        for line in unit.read_text().splitlines()
        if line.startswith("ExecStart=")
    ]
    store = re.escape(str(STORE))
    if (
        len(commands) != 1
        or len(commands[0]) != 2
        or not re.fullmatch(store + r"/[a-z0-9]{32}-hm-setup-env", commands[0][0])
        or not re.fullmatch(
            store + r"/[a-z0-9]{32}-home-manager-generation", commands[0][1]
        )
    ):
        raise ValueError("Unexpected immutable Home Manager unit command")
    generation = Path(commands[0][1])
    files = (generation / "home-files").resolve(strict=True)
    meta = files.stat()
    if (
        files.parent != STORE
        or not files.name.endswith("-home-manager-files")
        or not stat.S_ISDIR(meta.st_mode)
        or meta.st_uid != 0
        or meta.st_mode & 0o222
    ):
        raise ValueError("Recovery home files must be an immutable generation")
    return files


def expected_links(relative, managed_home_files, additional_home_files):
    roots = ([managed_home_files] if managed_home_files else []) + list(
        additional_home_files
    )
    return {str(Path(root).resolve() / relative) for root in roots}


def verify_cache(
    cache,
    command,
    managed_home_files=None,
    cache_relative=None,
    additional_home_files=(),
):
    cache = Path(cache)
    if cache.is_symlink():
        expected = (
            expected_links(cache_relative, managed_home_files, additional_home_files)
            if cache_relative
            else set()
        )
        if (
            cache.lstat().st_uid != os.getuid()
            or os.readlink(cache) not in expected
            or not cache.exists()
        ):
            raise ValueError(
                "foreign or dangling cache link; preserve and review it before activation"
            )
        return
    if not cache.exists():
        return
    if not cache.is_dir() or cache.stat().st_uid != os.getuid():
        raise ValueError("cache ownership/type mismatch; no data changed")
    directories = [p.name for p in cache.iterdir() if p.is_dir() or p.is_symlink()]
    if directories != ["2.1.1"]:
        raise ValueError(
            "cache layout/version requires preservation-first migration; no data changed"
        )
    verify(cache / "2.1.1", command, allow_extras=True)


def verify_owned_links(
    home, relatives, managed_home_files=None, additional_home_files=()
):
    home = Path(home)
    for relative in relatives:
        parts = Path(relative).parts
        if Path(relative).is_absolute() or ".." in parts:
            raise ValueError("immutable source path must be home-relative")
        path = home / relative
        for parent in path.parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise ValueError(
                    "immutable source parent is redirected; no path changed"
                )
        if not path.exists() and not path.is_symlink():
            continue
        expected = expected_links(relative, managed_home_files, additional_home_files)
        if (
            not path.is_symlink()
            or path.lstat().st_uid != os.getuid()
            or os.readlink(path) not in expected
            or not path.exists()
        ):
            raise ValueError(
                "immutable source/launcher collision; preserve and review it before activation"
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root")
    parser.add_argument("--command")
    parser.add_argument("--cache", action="store_true")
    parser.add_argument("--managed-home-files")
    parser.add_argument("--cache-relative")
    parser.add_argument("--pending-home-files")
    parser.add_argument("--system-home-manager-unit")
    parser.add_argument("--home")
    parser.add_argument("--owned-link", action="append", default=[])
    args = parser.parse_args()
    try:
        if args.cache:
            if not args.command:
                parser.error("--cache requires --command")
            additional = []
            if args.pending_home_files:
                additional.append(args.pending_home_files)
            if args.system_home_manager_unit:
                additional.append(system_home_files(args.system_home_manager_unit))
            if args.owned_link:
                if not args.home:
                    parser.error("--owned-link requires --home")
                verify_owned_links(
                    args.home, args.owned_link, args.managed_home_files, additional
                )
            verify_cache(
                args.root,
                args.command,
                args.managed_home_files,
                args.cache_relative,
                additional,
            )
        else:
            verify(args.root, args.command)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, "Blender plugin: " + str(error) + "\n")


if __name__ == "__main__":
    main()
