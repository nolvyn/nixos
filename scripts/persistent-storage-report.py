#!/usr/bin/env python3
"""Report persistence metadata and growth; never read payloads or remove data."""

import argparse
import datetime
import json
import os
from pathlib import Path
import re
import stat


def mounts_from(path):
    mounts = set()
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 6:
            mounts.add(re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), fields[4]))
    return mounts


def collect(root, declarations, mounts):
    root = Path(root)
    device = root.stat().st_dev
    declared = {}
    bindings = []
    for entry in declarations:
        source = os.path.normpath(entry["source"])
        if not source.startswith(str(root) + "/"):
            raise ValueError("Persistence declaration falls outside report root")
        declared[source] = entry["target"]
        try:
            status = (
                "mounted" if os.path.samefile(source, entry["target"]) else "mismatch"
            )
        except PermissionError:
            status = "unreadable"
        except FileNotFoundError:
            status = "missing"
        bindings.append({"source": source, "target": entry["target"], "status": status})

    sizes = {}
    categories = {}
    skipped = {"protected": 0, "symlinks": 0, "mounts": 0, "unreadable": 0}
    hardlinks = set()
    total = 0

    def visit(path, bucket=None):
        nonlocal total
        if path.name in {"secrets", "assets"}:
            skipped["protected"] += 1
            return
        try:
            metadata = path.lstat()
            if stat.S_ISLNK(metadata.st_mode):
                skipped["symlinks"] += 1
                return
            if metadata.st_dev != device or (path != root and str(path) in mounts):
                skipped["mounts"] += 1
                return
            if not (stat.S_ISREG(metadata.st_mode) or stat.S_ISDIR(metadata.st_mode)):
                return
            if stat.S_ISREG(metadata.st_mode) and metadata.st_nlink > 1:
                identity = (metadata.st_dev, metadata.st_ino)
                if identity in hardlinks:
                    return
                hardlinks.add(identity)
            if bucket is None:
                if str(path) in declared:
                    bucket = str(path)
                    categories[bucket] = "declared"
                elif path != root and not any(
                    p.startswith(str(path) + "/") for p in declared
                ):
                    bucket = str(path)
                    categories[bucket] = "undeclared"
            allocated = metadata.st_blocks * 512
            total += allocated
            if bucket is not None:
                sizes[bucket] = sizes.get(bucket, 0) + allocated
            if stat.S_ISDIR(metadata.st_mode):
                with os.scandir(path) as children:
                    for child in children:
                        visit(Path(child.path), bucket)
        except (OSError, RecursionError):
            skipped["unreadable"] += 1

    visit(root)
    return {
        "schema": 1,
        "root": str(root),
        "readable_allocated_bytes": total,
        "entries": [
            {"path": p, "bytes": size, "category": categories[p]}
            for p, size in sorted(sizes.items(), key=lambda item: (-item[1], item[0]))
        ],
        "bindings": bindings,
        "skipped": skipped,
    }


def size_text(value):
    sign = "-" if value < 0 else ""
    amount = abs(value)
    for unit in ["B", "KiB", "MiB", "GiB", "TiB"]:
        if amount < 1024 or unit == "TiB":
            return f"{sign}{amount:.1f} {unit}"
        amount /= 1024


def render(report, previous, output):
    previous_sizes = {e["path"]: e["bytes"] for e in previous.get("entries", [])}
    comparable = (
        previous.get("root") == report["root"]
        and previous.get("schema") == report["schema"]
    )
    candidate_bytes = sum(
        e["bytes"] for e in report["entries"] if e["category"] == "undeclared"
    )
    missing = sum(b["status"] in {"missing", "mismatch"} for b in report["bindings"])
    uncertain = sum(b["status"] == "unreadable" for b in report["bindings"])
    notice = (
        f"Monthly storage report: {report['month']}\n"
        f"Readable persisted data: {size_text(report['readable_allocated_bytes'])}; "
        f"outside current declarations: {size_text(candidate_bytes)} (review only).\n"
    )
    if comparable:
        notice += f"Change since {previous['month']}: {size_text(report['readable_allocated_bytes'] - previous['readable_allocated_bytes'])}.\n"
    if missing or uncertain or report["skipped"]["unreadable"]:
        notice += f"Partial inspection: {missing} missing/mismatched bindings, {uncertain} unverified bindings, {report['skipped']['unreadable']} unreadable paths.\n"
    notice += f"Details: {output / 'latest.txt'}\n"
    lines = [
        notice,
        "Sizes are allocated-block estimates; Btrfs compression/reflinks can affect physical usage.",
        "Protected directories, symlinks, nested mounts, and unreadable data are excluded.",
        "Undeclared paths are candidates for review, never deletion instructions.",
        "",
        "Largest persisted areas:",
    ]
    for entry in report["entries"][:15]:
        delta = ""
        if comparable and entry["path"] in previous_sizes:
            delta = (
                f"; change {size_text(entry['bytes'] - previous_sizes[entry['path']])}"
            )
        lines.append(
            f"{size_text(entry['bytes'])}: {json.dumps(entry['path'], ensure_ascii=False)} [{entry['category']}{delta}]"
        )
    lines += ["", "Paths outside current declarations:"]
    for entry in report["entries"]:
        if entry["category"] == "undeclared":
            lines.append(
                f"{size_text(entry['bytes'])}: {json.dumps(entry['path'], ensure_ascii=False)}"
            )
    lines += ["", "Unverified or missing bindings:"]
    for binding in report["bindings"]:
        if binding["status"] != "mounted":
            lines.append(
                f"{binding['status']}: {json.dumps(binding['source'], ensure_ascii=False)} -> {json.dumps(binding['target'], ensure_ascii=False)}"
            )
    return notice, "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--state-dir", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    root = Path(args.root)
    mounts = mounts_from("/proc/self/mountinfo")
    if str(root) not in mounts or root.is_symlink():
        raise SystemExit("Refusing report: persistence root is not a direct mount")
    output = Path(args.state_dir)
    if output.is_symlink():
        raise SystemExit("Refusing symlink report directory")
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc)
    month = now.strftime("%Y-%m")
    previous = {}
    for snapshot in sorted(output.glob("????-??.json"), reverse=True):
        if snapshot.stem < month and not snapshot.is_symlink():
            try:
                candidate = json.loads(snapshot.read_text())
                if isinstance(candidate, dict) and isinstance(
                    candidate.get("entries"), list
                ):
                    previous = candidate
                    break
            except (OSError, ValueError):
                continue
    report = collect(root, json.loads(Path(args.manifest).read_text()), mounts)
    report.update(month=month, generated_at=now.isoformat())
    notice, details = render(report, previous, output)
    for name, text in [
        (f"{month}.json", json.dumps(report, indent=2) + "\n"),
        ("latest.txt", details),
        ("notice.txt", notice),
    ]:
        # Exclusive creation also prevents following a pre-existing staging link.
        staging = output / f".{name}.{os.getpid()}"
        with staging.open("x") as handle:
            handle.write(text)
        os.replace(staging, output / name)
    print("Monthly storage report saved.")


if __name__ == "__main__":
    main()
