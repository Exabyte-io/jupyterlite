#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SKIP_PREFIXES = ("emfs:", "nodeps:", "http://", "https://")
PYODIDE_BUILTINS = {"lzma", "sqlite3", "ssl", "h5py", "lmdb"}
ALLOWED_WHEEL_SUFFIXES = ("-py3-none-any.whl", "-py2.py3-none-any.whl")


def normalize_name(package_name):
    return re.sub(r"[-_.]+", "-", package_name).lower()


def package_name_from_spec(package_spec):
    package_spec = package_spec.split("[", 1)[0]
    package_spec = re.split(r"[<>=!~]", package_spec, maxsplit=1)[0]
    return normalize_name(package_spec.strip())


def is_skippable(package_spec, pyodide_runtime_packages):
    if not package_spec or any(package_spec.startswith(prefix) for prefix in SKIP_PREFIXES):
        return True
    package_name = package_name_from_spec(package_spec)
    return package_name in PYODIDE_BUILTINS or package_name in pyodide_runtime_packages


def preserve_existing_wheel(filename):
    return "emscripten" in filename


def collect_package_specs(config, pyodide_runtime_packages):
    package_specs = []
    seen = set()
    for section in ("packages_pyodide", "packages_common"):
        for package_spec in config.get("default", {}).get(section) or []:
            if not is_skippable(package_spec, pyodide_runtime_packages) and package_spec not in seen:
                seen.add(package_spec)
                package_specs.append(package_spec)
    for notebook in config.get("notebooks", []) or []:
        for section in ("packages_pyodide", "packages_common"):
            for package_spec in notebook.get(section) or []:
                if not is_skippable(package_spec, pyodide_runtime_packages) and package_spec not in seen:
                    seen.add(package_spec)
                    package_specs.append(package_spec)
    return package_specs, seen


def load_pyodide_runtime_packages(pyodide_lock_file):
    lock_path = Path(pyodide_lock_file)
    if not lock_path.is_file():
        return set()
    with lock_path.open() as stream:
        pyodide_lock = yaml.safe_load(stream)
    return {normalize_name(name) for name in (pyodide_lock.get("packages") or {}).keys()}


def collect_dependency_wheels(config_file, packages_dir, pyodide_lock_file, runtime_pinned_specs):
    with open(config_file) as stream:
        config = yaml.safe_load(stream)

    pyodide_runtime_packages = load_pyodide_runtime_packages(pyodide_lock_file)
    package_specs, seen = collect_package_specs(config, pyodide_runtime_packages)

    print(
        "Collecting local dependency wheels for "
        f"{len(package_specs)} packages (runtime pins: {len(runtime_pinned_specs)})."
    )

    for pinned_spec in runtime_pinned_specs:
        if pinned_spec not in seen:
            package_specs.append(pinned_spec)

    os.makedirs(packages_dir, exist_ok=True)
    for filename in sorted(os.listdir(packages_dir)):
        if not filename.endswith(".whl"):
            continue
        if preserve_existing_wheel(filename):
            continue
        os.remove(os.path.join(packages_dir, filename))

    tmp_dir = tempfile.mkdtemp(prefix="jupyterlite-wheel-collect-")
    try:
        for package_spec in sorted(package_specs):
            result = subprocess.run(
                [sys.executable, "-m", "pip", "download", "--only-binary=:all:", "-d", tmp_dir, package_spec],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print(f"  Skipped (download failed): {package_spec}")

        copied = 0
        for filename in sorted(os.listdir(tmp_dir)):
            source_path = os.path.join(tmp_dir, filename)
            if not os.path.isfile(source_path):
                continue
            is_wheel = filename.endswith(".whl")
            is_allowed_wheel = is_wheel and (
                filename.endswith(ALLOWED_WHEEL_SUFFIXES) or "emscripten" in filename
            )
            if not is_allowed_wheel:
                continue
            shutil.copy2(source_path, os.path.join(packages_dir, filename))
            copied += 1

        print(f"Collected {copied} compatible wheels into {packages_dir}.")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-file", required=True)
    parser.add_argument("--packages-dir", required=True)
    parser.add_argument("--pyodide-lock-file", required=True)
    parser.add_argument("--runtime-pinned-specs", default="")
    return parser.parse_args()


def main():
    args = parse_args()
    runtime_pinned_specs = [spec for spec in args.runtime_pinned_specs.split(";") if spec]
    collect_dependency_wheels(
        config_file=args.config_file,
        packages_dir=args.packages_dir,
        pyodide_lock_file=args.pyodide_lock_file,
        runtime_pinned_specs=runtime_pinned_specs,
    )


if __name__ == "__main__":
    main()
