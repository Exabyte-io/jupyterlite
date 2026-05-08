#!/bin/bash

ensure_python_version_installed() {
    local PYTHON_VERSION=$1
    if ! pyenv versions | grep -q $PYTHON_VERSION; then
        echo "Python $PYTHON_VERSION not found. Installing..."
        pyenv install $PYTHON_VERSION
    fi
    pyenv local $PYTHON_VERSION
}

ensure_node_version_installed() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    if ! nvm list | grep -q $NODE_VERSION; then
        echo "Node.js $NODE_VERSION not found. Installing..."
        nvm install $NODE_VERSION
    fi
    nvm use $NODE_VERSION
}

create_virtualenv() {
    local VENV_NAME=$1
    if [ ! -d ${VENV_NAME} ]; then
        python -m venv ${VENV_NAME}
    fi
    source ${VENV_NAME}/bin/activate
    echo "Virtual environment created and activated: ${VENV_NAME}"
}

create_extension_template() {
    local COOKIECUTTER_OPTIONS=("$@")
    local COOKIECUTTER_TEMPLATE_PATH="$HOME/.cookiecutters/extension-cookiecutter-ts"
    pip install cookiecutter jupyterlab==4 jupyterlite-core
    # Use cookiecutter with the template path if it exists, otherwise use the URL
    if [ ! -d "$COOKIECUTTER_TEMPLATE_PATH" ]; then
        cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
        echo "Created extension using cookiecutter template."
    else
        # COOKIECUTTER_OPTIONS[0]="$COOKIECUTTER_TEMPLATE_PATH"
        cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
        echo "Created extension using cached cookiecutter template."
    fi
}

build_extension() {
    local EXTENSION_NAME=$1
    local PACKAGE_ROOT_PATH=$2
    # Following https://github.com/jupyterlite/jupyterlite/blob/dee7a211ec0fc3f18f4d39b1b9fce9b508d4d0df/docs/howto/configure/advanced/iframe.md
    # Our extension is treated as a separate package in ./extensions/src directory
    # Copy the extension source file that we changed to the cookiecutter template in ./extensions/dist directory
    # It places the source file in the dist/EXTENSION_NAME/src file that will be used for the build
    SRC_FILE="$(realpath "${PACKAGE_ROOT_PATH}/extensions/src/${EXTENSION_NAME}/index.ts")"
    DEST_DIR="$(realpath "${PACKAGE_ROOT_PATH}/extensions/dist/${EXTENSION_NAME}/src")"
    DEST_FILE="${DEST_DIR}/index.ts"

    echo "DEBUG: copying $SRC_FILE to $DEST_FILE"

    if [ -f "$SRC_FILE" ] && [ -d "$DEST_DIR" ]; then
        cp "$SRC_FILE" "$DEST_FILE"
    else
        echo "Source file not found. Skipping copy."
        exit 1
    fi

    cd "${PACKAGE_ROOT_PATH}/extensions/dist/${EXTENSION_NAME}" || exit 1

    # To avoid 'Intl' has no exported member named 'ResolvedRelativeTimeFormatOptions'.
    # node_modules/@jupyterlab/coreutils/lib/time.d.ts:5:28
    sed -i.bak '/"compilerOptions": {/a\'$'\n''  "skipLibCheck": true,'$'\n' tsconfig.json

    # The extension is treated here as a separate package so it requires to have a yarn.lock file
    touch yarn.lock
    pip install -ve .

    jupyter labextension develop --overwrite .

    # Install dependencies
    jlpm add @jupyterlab/application @jupyterlab/notebook @mat3ra/esse

    # Build the extension
    jlpm run build
    cd - || exit 1
}

# For distribution of the whole package from our repo
download_config_packages() {
    local CONFIG_FILE=$1
    local WHEELS_DIR=$2

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "Config file not found at ${CONFIG_FILE}, skipping package preload."
        return
    fi

    pip install pyyaml --quiet
    rm -rf "${WHEELS_DIR}"
    mkdir -p "${WHEELS_DIR}"
    echo "Downloading pure-Python wheels from ${CONFIG_FILE} to ${WHEELS_DIR}..."
    python3 - "${CONFIG_FILE}" "${WHEELS_DIR}" <<'PYEOF'
import os, subprocess, sys, yaml

SKIP_PREFIXES = ('emfs:', 'nodeps:', 'http://', 'https://')
PYODIDE_BUILTINS = {'lzma', 'sqlite3', 'ssl', 'h5py', 'lmdb'}

def is_skippable(pkg):
    return not pkg or pkg in PYODIDE_BUILTINS or any(pkg.startswith(p) for p in SKIP_PREFIXES)

config_file, wheels_dir = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    config = yaml.safe_load(f)

packages = set()
for section in ('packages_pyodide', 'packages_common'):
    for pkg in (config.get('default', {}).get(section) or []):
        if not is_skippable(pkg):
            packages.add(pkg)
for nb in (config.get('notebooks', []) or []):
    for section in ('packages_pyodide', 'packages_common'):
        for pkg in (nb.get(section) or []):
            if not is_skippable(pkg):
                packages.add(pkg)

print(f"Found {len(packages)} candidate packages.")
for pkg in sorted(packages):
    r = subprocess.run(
        [sys.executable, '-m', 'pip', 'download',
         '--no-deps', '--only-binary=:all:', '-d', wheels_dir, pkg],
        capture_output=True, text=True
    )
    if r.returncode != 0:
        print(f"  Skipped (no binary wheel): {pkg}")

for fname in os.listdir(wheels_dir):
    if fname.endswith('.whl') and not fname.endswith('-none-any.whl'):
        os.remove(os.path.join(wheels_dir, fname))
        print(f"  Removed platform-specific wheel: {fname}")
PYEOF
}

unpack_preinstalled_wheels() {
    local PREINSTALLED_DIR=$1
    shift

    rm -rf "${PREINSTALLED_DIR}"
    mkdir -p "${PREINSTALLED_DIR}"

    python3 - "${PREINSTALLED_DIR}" "$@" <<'PYEOF'
import sys
import zipfile
from pathlib import Path

PYODIDE_PACKAGE_WHEEL_PREFIXES = (
    "jsonschema-",
    "numpy-",
    "pandas-",
    "pydantic-",
    "pydantic_core-",
    "pyyaml-",
    "scipy-",
    "typing_extensions-",
)

preinstalled_dir = Path(sys.argv[1])
wheel_paths = [Path(path) for path in sys.argv[2:]]

for wheel_path in wheel_paths:
    if not wheel_path.exists() or wheel_path.suffix != ".whl":
        continue
    if wheel_path.name.startswith(PYODIDE_PACKAGE_WHEEL_PREFIXES):
        continue
    if not wheel_path.name.endswith(("none-any.whl", "py2.py3-none-any.whl")):
        continue
    with zipfile.ZipFile(wheel_path) as wheel:
        # Avoid shadowing Pyodide's special `js` module.
        if any(name.startswith("js/") for name in wheel.namelist()):
            print(f"Skipped preinstall (contains top-level js package): {wheel_path.name}")
            continue
        wheel.extractall(preinstalled_dir)
        print(f"Preinstalled {wheel_path.name}")
PYEOF
}

patch_pyodide_startup_packages() {
    local CONFIG_FILE=$1
    local PYPI_INDEX_FILE=$2
    local JUPYTER_LITE_JSON=$3

    if [[ ! -f "${CONFIG_FILE}" || ! -f "${PYPI_INDEX_FILE}" || ! -f "${JUPYTER_LITE_JSON}" ]]; then
        echo "Missing config, pypi index, or jupyter-lite.json. Skipping Pyodide startup package patch."
        return
    fi

    python3 - "${CONFIG_FILE}" "${PYPI_INDEX_FILE}" "${JUPYTER_LITE_JSON}" <<'PYEOF'
import json
import os
import re
import sys

import yaml

SKIP_PREFIXES = ("nodeps:", "http://", "https://")
PYODIDE_PACKAGES = {
    "attrs",
    "jsonschema",
    "jsonschema-specifications",
    "lzma",
    "micropip",
    "numpy",
    "pandas",
    "pydantic",
    "pydantic-core",
    "pyyaml",
    "referencing",
    "rpds-py",
    "scipy",
    "sqlite3",
    "typing-extensions",
}


def normalize_name(package_name):
    return re.sub(r"[-_.]+", "-", package_name).lower()


def package_name_from_spec(package_spec):
    package_spec = package_spec.split("[", 1)[0]
    package_spec = re.split(r"[<>=!~]", package_spec, maxsplit=1)[0]
    return normalize_name(package_spec.strip())


def add_package(package_spec, packages, package_names):
    if not package_spec or any(package_spec.startswith(prefix) for prefix in SKIP_PREFIXES):
        return
    if package_spec.startswith("emfs:/"):
        package_name = os.path.basename(package_spec)
    else:
        package_name = package_name_from_spec(package_spec)
    if package_name not in package_names:
        package_names.add(package_name)
        packages.append(package_spec)


def collect_packages(config):
    packages = []
    package_names = set()
    for section in ("packages_pyodide", "packages_common"):
        for package_spec in config.get("default", {}).get(section) or []:
            add_package(package_spec, packages, package_names)
    for notebook in config.get("notebooks", []) or []:
        for section in ("packages_pyodide", "packages_common"):
            for package_spec in notebook.get(section) or []:
                add_package(package_spec, packages, package_names)
    return packages


def wheel_filename_from_emfs(package_spec):
    if package_spec.startswith("emfs:/"):
        return os.path.basename(package_spec)
    return None


def startup_package(package_spec, wheel_index):
    emfs_filename = wheel_filename_from_emfs(package_spec)
    if emfs_filename:
        return None

    normalized_name = package_name_from_spec(package_spec)
    if normalized_name in PYODIDE_PACKAGES:
        return normalized_name

    return None


config_file, pypi_index_file, jupyter_lite_json = sys.argv[1:]
with open(config_file) as stream:
    config = yaml.safe_load(stream)
with open(pypi_index_file) as stream:
    wheel_index = json.load(stream)
with open(jupyter_lite_json) as stream:
    jupyter_lite = json.load(stream)

startup_packages = []
for package_spec in collect_packages(config):
    package = startup_package(package_spec, wheel_index)
    if package:
        startup_packages.append(package)

settings = jupyter_lite["jupyter-config-data"].setdefault("litePluginSettings", {})
kernel = settings.setdefault("@jupyterlite/pyodide-kernel-extension:kernel", {})
load_options = kernel.setdefault("loadPyodideOptions", {})
load_options["packages"] = startup_packages
env = load_options.setdefault("env", {})
env["PYTHONPATH"] = "/drive/preinstalled"

with open(jupyter_lite_json, "w") as stream:
    json.dump(jupyter_lite, stream, indent=2)

print(f"Configured {len(startup_packages)} Pyodide startup packages.")
PYEOF
}

download_pyodide() {
    local VERSION=$1
    local DEST_DIR=$2
    local TARBALL="pyodide-${VERSION}.tar.bz2"
    local URL="https://github.com/pyodide/pyodide/releases/download/${VERSION}/${TARBALL}"
    local TMP_TARBALL="/tmp/${TARBALL}"

    if [[ -d "${DEST_DIR}" ]]; then
        echo "Pyodide ${VERSION} already present at ${DEST_DIR}, skipping download."
        return
    fi

    echo "Downloading pyodide ${VERSION} from ${URL}..."
    mkdir -p "$(dirname "${DEST_DIR}")"
    curl -L "${URL}" -o "${TMP_TARBALL}"
    tar -xjf "${TMP_TARBALL}" -C "$(dirname "${DEST_DIR}")"
    rm "${TMP_TARBALL}"
    echo "Pyodide ${VERSION} downloaded to ${DEST_DIR}."
}

patch_pyodide_url() {
    local JUPYTER_LITE_JSON=$1
    local PYODIDE_URL=$2
    python3 - <<EOF
import json
with open('${JUPYTER_LITE_JSON}', 'r') as f:
    config = json.load(f)
settings = config['jupyter-config-data'].setdefault('litePluginSettings', {})
kernel = settings.setdefault('@jupyterlite/pyodide-kernel-extension:kernel', {})
kernel['pyodideUrl'] = '${PYODIDE_URL}'
with open('${JUPYTER_LITE_JSON}', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    echo "Set pyodideUrl to '${PYODIDE_URL}' in ${JUPYTER_LITE_JSON}."
}

add_line_to_file_if_not_present() {
    local LINE=$1
    local FILE=$2
    grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}

cleanup() {
    local EXTENSION_NAME=$1
    rm -rf ${PACKAGE_ROOT_PATH}/dist/extensions/${EXTENSION_NAME}
    rm -rf ${PACKAGE_ROOT_PATH}/extensions/dist/${EXTENSION_NAME}
}
