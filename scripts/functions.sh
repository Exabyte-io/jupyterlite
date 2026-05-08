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
collect_config_dependency_wheels() {
    local CONFIG_FILE=$1
    local PACKAGES_DIR=$2

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "Config file not found at ${CONFIG_FILE}, skipping dependency wheel collection."
        return
    fi

    mkdir -p "${PACKAGES_DIR}"

    python3 - "${CONFIG_FILE}" "${PACKAGES_DIR}" <<'PYEOF'
import os
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

SKIP_PREFIXES = ("emfs:", "nodeps:", "http://", "https://")
PYODIDE_BUILTINS = {"lzma", "sqlite3", "ssl", "h5py", "lmdb"}
PYODIDE_RUNTIME_PACKAGES = {
    "numpy",
    "pandas",
    "scipy",
    "pyyaml",
    "jsonschema",
    "typing-extensions",
    "pydantic",
}
ALLOWED_WHEEL_SUFFIXES = ("-py3-none-any.whl", "-py2.py3-none-any.whl")
RUNTIME_PINNED_SPECS = (
    "ipython==8.31.0",
)


def normalize_name(package_name):
    return re.sub(r"[-_.]+", "-", package_name).lower()


def package_name_from_spec(package_spec):
    package_spec = package_spec.split("[", 1)[0]
    package_spec = re.split(r"[<>=!~]", package_spec, maxsplit=1)[0]
    return normalize_name(package_spec.strip())


def is_skippable(package_spec):
    if not package_spec or any(package_spec.startswith(prefix) for prefix in SKIP_PREFIXES):
        return True
    package_name = package_name_from_spec(package_spec)
    return package_name in PYODIDE_BUILTINS or package_name in PYODIDE_RUNTIME_PACKAGES


def preserve_existing_wheel(filename):
    return "emscripten" in filename


config_file, packages_dir = sys.argv[1], sys.argv[2]
with open(config_file) as stream:
    config = yaml.safe_load(stream)

package_specs = []
seen = set()
for section in ("packages_pyodide", "packages_common"):
    for package_spec in config.get("default", {}).get(section) or []:
        if not is_skippable(package_spec) and package_spec not in seen:
            seen.add(package_spec)
            package_specs.append(package_spec)
for notebook in config.get("notebooks", []) or []:
    for section in ("packages_pyodide", "packages_common"):
        for package_spec in notebook.get(section) or []:
            if not is_skippable(package_spec) and package_spec not in seen:
                seen.add(package_spec)
                package_specs.append(package_spec)

print(f"Collecting local dependency wheels for {len(package_specs)} packages...")

for pinned_spec in RUNTIME_PINNED_SPECS:
    if pinned_spec not in seen:
        package_specs.append(pinned_spec)

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
PYEOF
}


download_pyodide() {
    local VERSION=$1
    local DEST_DIR=$2
    local TARBALL="pyodide-${VERSION}.tar.bz2"
    local URL="https://github.com/pyodide/pyodide/releases/download/${VERSION}/${TARBALL}"
    local TMP_TARBALL="/tmp/${TARBALL}"

    if [[ -f "${DEST_DIR}/pyodide.js" ]]; then
        echo "Pyodide ${VERSION} already present at ${DEST_DIR}, skipping download."
        return
    fi
    rm -rf "${DEST_DIR}"

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

patch_pyodide_startup_packages() {
    local JUPYTER_LITE_JSON=$1
    python3 - <<EOF
import json
with open('${JUPYTER_LITE_JSON}', 'r') as f:
    config = json.load(f)
settings = config['jupyter-config-data'].setdefault('litePluginSettings', {})
kernel = settings.setdefault('@jupyterlite/pyodide-kernel-extension:kernel', {})
kernel['disablePyPIFallback'] = True
load_options = kernel.setdefault('loadPyodideOptions', {})
load_options['packages'] = [
    'lzma',
    'sqlite3',
    'pyyaml',
    'numpy',
    'scipy',
    'jsonschema',
    'pandas',
]
with open('${JUPYTER_LITE_JSON}', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    echo "Set loadPyodideOptions.packages in ${JUPYTER_LITE_JSON}."
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
