#!/usr/bin/env python3
"""Preserve a real Blender cache before a reviewed migration or old-layout rollback.

Quit Codex and all plugin consumers first. --quiescent records that operator
prerequisite; this tool cannot verify that all consumers have stopped. It never
stops processes, deletes data, restores a cache over another path, or activates
Home Manager. Default mode only prints the plan.
"""

import argparse
import datetime
import json
import os
from pathlib import Path
import stat
import uuid


def preserve(codex_home, apply=False, quiescent=False):
    home = Path(codex_home).absolute()
    if home.is_symlink() or not home.is_dir() or home.stat().st_uid != os.getuid():
        raise ValueError("Codex home must be an owned real directory")
    cache = home / "plugins/cache/home-manager/mcp-for-blender"
    # Do not traverse a redirected parent to a different owner's tree.
    for parent in [home / "plugins", home / "plugins/cache", cache.parent]:
        if (
            parent.is_symlink()
            or not parent.is_dir()
            or parent.stat().st_uid != os.getuid()
        ):
            raise ValueError("cache parent must be an owned real directory")
    if cache.is_symlink() or not cache.is_dir() or cache.stat().st_uid != os.getuid():
        raise ValueError(
            "preservation requires an owned real Blender cache; no path changed"
        )
    backup_root = home / "hm-migration-backups"
    if backup_root.exists() or backup_root.is_symlink():
        if (
            backup_root.is_symlink()
            or not backup_root.is_dir()
            or backup_root.stat().st_uid != os.getuid()
        ):
            raise ValueError("backup parent ownership/type mismatch")
        if stat.S_IMODE(backup_root.stat().st_mode) != 0o700:
            raise ValueError(
                "backup parent must already be private0700; no permissions changed"
            )
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = backup_root / ("blender-cache-" + stamp + "-" + uuid.uuid4().hex)
    plan = {
        "cache": str(cache),
        "backup": str(backup),
        "applied": False,
        "quiescence_is_external_prerequisite": True,
    }
    if not apply:
        return plan
    if not quiescent:
        raise ValueError("--apply requires prior consumer quiescence and --quiescent")
    before = cache.lstat()
    backup_root.mkdir(mode=0o700, exist_ok=True)
    backup.mkdir(mode=0o700)
    destination = backup / "cache"
    # Same Codex-home mount; rename preserves every entry without reading secrets.
    cache.rename(destination)
    after = destination.lstat()
    if (
        before.st_dev,
        before.st_ino,
        before.st_uid,
        before.st_gid,
        before.st_mode,
        before.st_mtime_ns,
    ) != (
        after.st_dev,
        after.st_ino,
        after.st_uid,
        after.st_gid,
        after.st_mode,
        after.st_mtime_ns,
    ):
        raise RuntimeError("preserved cache metadata differs; retained for review")
    plan.update(applied=True, backup=str(destination), metadata_preserved=True)
    receipt = backup / "receipt.json"
    receipt.write_text(json.dumps(plan, indent=2) + "\n")
    receipt.chmod(0o600)
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-home", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--quiescent", action="store_true")
    args = parser.parse_args()
    try:
        print(
            json.dumps(preserve(args.codex_home, args.apply, args.quiescent), indent=2)
        )
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, "Blender cache preservation: " + str(error) + "\n")


if __name__ == "__main__":
    main()
