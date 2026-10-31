#!/usr/bin/env python3
"""Exercise the actual pinned Home Manager patch assertions in disposable inputs."""

import json
import os
from pathlib import Path
import subprocess


def run(repo, root):
    env = os.environ | {"BLENDER_COMPAT_REPO": str(repo)}
    expression = (
        'let f=builtins.getFlake (builtins.getEnv "BLENDER_COMPAT_REPO"); '
        "in { hm=toString f.inputs.home-manager.outPath; "
        'lib=toString f.inputs.nixpkgs.outPath+"/lib"; }'
    )
    query = subprocess.run(
        [
            "nix",
            "eval",
            "--offline",
            "--no-write-lock-file",
            "--impure",
            "--json",
            "--expr",
            expression,
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert query.returncode == 0, query.stderr
    paths = json.loads(query.stdout)
    source = Path(paths["hm"]) / "modules/programs/codex"
    original = {
        name: (source / name).read_text() for name in ["lib.nix", "default.nix"]
    }
    anchors = [
        (
            "lib.nix",
            'path = "./${homeRelativePluginsCacheDir}/${pluginsMarketplaceName}/${mkPluginPathName plugin}/${mkPluginPathVersion plugin}";',
        ),
        ("default.nix", "              ) staticPluginEntries)"),
        ("default.nix", "./lib.nix"),
        ("default.nix", "./options.nix"),
        ("default.nix", "./normalize-plugins.py"),
    ]
    helper = repo / "scripts/codex-local-source.nix"
    cases = [("unchanged", None, None)] + [
        (kind + "-" + str(i), i, kind)
        for i in range(len(anchors))
        for kind in ["missing", "duplicate"]
    ]
    results = []
    for label, index, kind in cases:
        directory = root / label
        directory.mkdir(parents=True)
        contents = dict(original)
        if index is not None:
            filename, anchor = anchors[index]
            assert contents[filename].count(anchor) == 1
            contents[filename] = contents[filename].replace(
                anchor, "" if kind == "missing" else anchor + anchor
            )
        for filename, text in contents.items():
            (directory / filename).write_text(text)
        command = (
            "import (builtins.toPath "
            + json.dumps(str(helper))
            + ") { lib=import (builtins.toPath "
            + json.dumps(paths["lib"])
            + "); codexModuleRoot=builtins.toPath "
            + json.dumps(str(directory))
            + "; }"
        )
        outcome = subprocess.run(
            ["nix-instantiate", "--eval", "--strict", "--json", "--expr", command],
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if index is None:
            assert outcome.returncode == 0, outcome.stderr
        else:
            assert outcome.returncode != 0 and (
                "is not equal to" in outcome.stderr or "assertion" in outcome.stderr
            ), outcome.stderr
        results.append(label)
    return {
        "passed": results,
        "count": len(results),
        "pinned_home_manager": paths["hm"],
    }
