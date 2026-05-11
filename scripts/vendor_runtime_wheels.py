#!/usr/bin/env python3

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

UNIVERSAL_WHEEL = re.compile(r"-(py3|py2\.py3)-none-any\.whl$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Download vendored wheels into a staging dir for --piplite-wheels "
            "(not under Jupyter contents — avoids a browsable /pypi/ tree)."
        ),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        required=True,
        help="dependencies/pyodide-packages.json (pyodide + runtime_vendor_requirements)",
    )
    parser.add_argument(
        "--wheel-dir",
        type=Path,
        required=True,
        help="Directory to write .whl files (not inside content/)",
    )
    return parser.parse_args()


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def runtime_vendor_lines(data: dict) -> list[str]:
    raw = data.get("runtime_vendor_requirements", [])
    out = []
    for item in raw:
        if not isinstance(item, str):
            continue
        line = item.strip()
        if line:
            out.append(line)
    return out


def write_requirements_temp(lines: list[str]) -> Path:
    fd, name = tempfile.mkstemp(suffix=".txt", text=True)
    path = Path(name)
    try:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    finally:
        os.close(fd)
    return path


def download_wheels(lines: list[str], dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    req_path = write_requirements_temp(lines)
    try:
        cmd = [
            sys.executable,
            "-m",
            "pip",
            "download",
            "-r",
            str(req_path),
            "-d",
            str(dest),
        ]
        subprocess.run(cmd, check=True)
    finally:
        req_path.unlink(missing_ok=True)


def remove_non_universal_wheels(dest: Path) -> tuple[int, int]:
    kept, removed = 0, 0
    for whl in dest.glob("*.whl"):
        if UNIVERSAL_WHEEL.search(whl.name):
            kept += 1
            continue
        whl.unlink()
        removed += 1
    return kept, removed


def main() -> int:
    args = parse_args()
    dest = args.wheel_dir
    data = load_manifest(args.manifest)
    lines = runtime_vendor_lines(data)
    if dest.exists():
        shutil.rmtree(dest)
    download_wheels(lines, dest)
    kept, removed = remove_non_universal_wheels(dest)
    print(
        f"Vendored universal wheels in {dest}: {kept} kept, {removed} non-pyodide-safe removed.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
