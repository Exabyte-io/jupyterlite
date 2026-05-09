#!/usr/bin/env python3

import argparse
import email
import json
import os
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path

from packaging.requirements import Requirement
from packaging.utils import canonicalize_name, parse_wheel_filename
from packaging.version import Version


STD_LIB_PACKAGES = {"lzma", "sqlite3", "ssl"}
BUILTIN_ONLY_PACKAGES = {"h5py", "lmdb", "ruamel-yaml-clib", "setuptools"}
KERNEL_BUNDLED_PACKAGES = {
    "certifi",
    "charset-normalizer",
    "fastjsonschema",
    "idna",
    "jsonschema",
    "jsonschema-specifications",
    "markupsafe",
    "matplotlib",
    "pyyaml",
    "referencing",
    "rpds-py",
    "scikit-image",
    "requests",
    "urllib3",
}


@dataclass(frozen=True)
class WheelRecord:
    path: Path
    filename: str
    name: str
    canonical_name: str
    version: Version
    requires: tuple[Requirement, ...]


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text())


def read_wheel_metadata(path: Path) -> WheelRecord:
    filename = path.name
    dist_name, version, _, _ = parse_wheel_filename(filename)
    metadata_name = None
    with zipfile.ZipFile(path) as wheel:
        for member in wheel.namelist():
            if member.endswith(".dist-info/METADATA"):
                metadata_name = member
                break
        if metadata_name is None:
            raise RuntimeError(f"Missing METADATA in wheel: {filename}")
        raw_metadata = wheel.read(metadata_name).decode("utf-8", errors="replace")
    message = email.message_from_string(raw_metadata)
    requires = tuple(
        Requirement(entry)
        for entry in message.get_all("Requires-Dist", [])
    )
    name = message.get("Name", dist_name)
    return WheelRecord(
        path=path,
        filename=filename,
        name=name,
        canonical_name=canonicalize_name(name),
        version=Version(str(version)),
        requires=requires,
    )


def build_wheel_index(wheel_dir: Path) -> tuple[dict[str, WheelRecord], dict[str, list[WheelRecord]]]:
    by_filename: dict[str, WheelRecord] = {}
    by_name: dict[str, list[WheelRecord]] = {}
    for wheel_path in sorted(wheel_dir.glob("*.whl")):
        record = read_wheel_metadata(wheel_path)
        by_filename[record.filename] = record
        by_name.setdefault(record.canonical_name, []).append(record)
    for candidates in by_name.values():
        candidates.sort(key=lambda item: item.version, reverse=True)
    return by_filename, by_name


def choose_wheel(
    requirement: Requirement,
    by_name: dict[str, list[WheelRecord]],
    preferred: dict[str, WheelRecord],
) -> WheelRecord:
    preferred_candidate = preferred.get(canonicalize_name(requirement.name))
    if preferred_candidate and requirement.specifier.contains(preferred_candidate.version, prereleases=True):
        return preferred_candidate
    candidates = by_name.get(canonicalize_name(requirement.name), [])
    for candidate in candidates:
        if requirement.specifier.contains(candidate.version, prereleases=True):
            return candidate
    raise RuntimeError(f"No local wheel satisfies requirement: {requirement}")


def resolve_closure(
    roots: list[WheelRecord | Requirement],
    by_name: dict[str, list[WheelRecord]],
    startup_packages: set[str],
    inherited_preferred: dict[str, WheelRecord] | None = None,
) -> list[WheelRecord]:
    preferred = dict(inherited_preferred or {})
    preferred.update({
        item.canonical_name: item
        for item in roots
        if isinstance(item, WheelRecord)
    })
    resolved: dict[str, WheelRecord] = {}
    pending: list[WheelRecord | Requirement] = roots[:]
    while pending:
        item = pending.pop()
        if isinstance(item, Requirement):
            package_name = canonicalize_name(item.name)
            if (
                package_name in startup_packages
                or package_name in STD_LIB_PACKAGES
                or package_name in BUILTIN_ONLY_PACKAGES
                or package_name in KERNEL_BUNDLED_PACKAGES
            ):
                continue
            wheel = choose_wheel(item, by_name, preferred)
        else:
            wheel = item
            if wheel.canonical_name in startup_packages:
                continue
        if wheel.canonical_name in resolved:
            continue
        resolved[wheel.canonical_name] = wheel
        for dependency in wheel.requires:
            if dependency.marker and not dependency.marker.evaluate({"sys_platform": "emscripten"}):
                continue
            dep_name = canonicalize_name(dependency.name)
            if (
                dep_name in startup_packages
                or dep_name in STD_LIB_PACKAGES
                or dep_name in BUILTIN_ONLY_PACKAGES
                or dep_name in KERNEL_BUNDLED_PACKAGES
            ):
                continue
            pending.append(dependency)
    return sorted(resolved.values(), key=lambda item: item.filename)


def unpack_wheel(wheel: WheelRecord, destination: Path) -> None:
    with zipfile.ZipFile(wheel.path) as archive:
        for member in archive.infolist():
            name = member.filename
            if name.endswith("/"):
                continue
            if name.startswith("js/"):
                continue
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)


def copy_runtime_wheelhouse(
    wheels: list[WheelRecord],
    by_filename: dict[str, WheelRecord],
    wheelhouse_dir: Path,
    all_json_path: Path,
) -> None:
    wheelhouse_dir.mkdir(parents=True, exist_ok=True)
    index: dict[str, dict] = {}
    for wheel in wheels:
        shutil.copy2(wheel.path, wheelhouse_dir / wheel.filename)
        package_entry = index.setdefault(wheel.name.lower(), {"releases": {}})
        package_entry["releases"].setdefault(str(wheel.version), []).append(
            {
                "comment_text": "",
                "digests": {},
                "downloads": -1,
                "filename": wheel.filename,
                "has_sig": False,
                "md5_digest": "",
                "packagetype": "bdist_wheel",
                "python_version": "py3",
                "requires_python": None,
                "size": wheel.path.stat().st_size,
                "upload_time": "",
                "upload_time_iso_8601": "",
                "url": f"./{wheel.filename}",
                "yanked": False,
                "yanked_reason": None,
            }
        )
    all_json_path.write_text(json.dumps(index, indent=2, sort_keys=True))


def notebook_key_to_path(name: str) -> str:
    if name.endswith(".ipynb"):
        return f"made/{name}"
    return name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--wheel-dir", required=True)
    parser.add_argument("--content-dir", required=True)
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    wheel_dir = Path(args.wheel_dir)
    content_dir = Path(args.content_dir)
    preinstalled_dir = content_dir / "preinstalled"
    runtime_wheelhouse_dir = content_dir / "pypi"
    runtime_manifest_path = content_dir / "pyodide-package-manifest.json"

    manifest = load_manifest(manifest_path)
    by_filename, by_name = build_wheel_index(wheel_dir)
    startup_packages = {
        canonicalize_name(name)
        for name in manifest["pyodide"]["startup_packages"]
    }

    preinstall_roots: list[WheelRecord | Requirement] = []
    for wheel_name in manifest["preinstall"]["wheels"]:
        wheel = by_filename.get(wheel_name)
        if wheel is None:
            raise RuntimeError(f"Missing vendored wheel: {wheel_name}")
        preinstall_roots.append(wheel)
    for requirement_text in manifest["preinstall"]["requirements"]:
        preinstall_roots.append(Requirement(requirement_text))

    preinstall_wheels = resolve_closure(preinstall_roots, by_name, startup_packages)

    if preinstalled_dir.exists():
        shutil.rmtree(preinstalled_dir)
    preinstalled_dir.mkdir(parents=True, exist_ok=True)
    for wheel in preinstall_wheels:
        unpack_wheel(wheel, preinstalled_dir)

    notebook_runtime: dict[str, list[str]] = {}
    all_runtime_wheels: dict[str, WheelRecord] = {wheel.filename: wheel for wheel in preinstall_wheels}
    preinstalled_names = {wheel.canonical_name for wheel in preinstall_wheels}
    preinstalled_preferred = {wheel.canonical_name: wheel for wheel in preinstall_wheels}

    for notebook in manifest["notebooks"]:
        roots: list[WheelRecord | Requirement] = []
        for wheel_name in notebook.get("wheels", []):
            wheel = by_filename.get(wheel_name)
            if wheel is None:
                raise RuntimeError(f"Missing vendored wheel: {wheel_name}")
            roots.append(wheel)
        for requirement_text in notebook.get("requirements", []):
            if (
                requirement_text in STD_LIB_PACKAGES
                or requirement_text in BUILTIN_ONLY_PACKAGES
                or requirement_text in KERNEL_BUNDLED_PACKAGES
            ):
                continue
            roots.append(Requirement(requirement_text))
        resolved = resolve_closure(
            roots,
            by_name,
            startup_packages,
            inherited_preferred=preinstalled_preferred,
        )
        filtered = [
            wheel for wheel in resolved
            if wheel.canonical_name not in preinstalled_names
        ]
        notebook_runtime[notebook_key_to_path(notebook["name"])] = [
            f"./pypi/{wheel.filename}" for wheel in filtered
        ]
        for wheel in filtered:
            all_runtime_wheels[wheel.filename] = wheel

    if runtime_wheelhouse_dir.exists():
        shutil.rmtree(runtime_wheelhouse_dir)
    copy_runtime_wheelhouse(
        list(sorted(all_runtime_wheels.values(), key=lambda item: item.filename)),
        by_filename,
        runtime_wheelhouse_dir,
        runtime_wheelhouse_dir / "all.json",
    )

    runtime_manifest = {
        "pyodide": manifest["pyodide"],
        "preinstalled": [wheel.filename for wheel in preinstall_wheels],
        "notebooks": notebook_runtime,
    }
    runtime_manifest_path.write_text(json.dumps(runtime_manifest, indent=2, sort_keys=True))

    print(
        json.dumps(
            {
                "startup_packages": manifest["pyodide"]["startup_packages"],
                "preinstalled_count": len(preinstall_wheels),
                "runtime_wheel_count": len(all_runtime_wheels),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
