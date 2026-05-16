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

# Builds the mat3ra-notebooks-utils wheel from the cloned api-examples repo and copies it
# into the pyodide distribution directory so it can be served as a local package.
build_and_copy_mat3ra_wheel() {
    local REPO_DIR=$1
    local DEST_DIR=$2
    local WHEEL_OUT_DIR="${REPO_DIR}/dist"

    python -m build --wheel --outdir "${WHEEL_OUT_DIR}" "${REPO_DIR}" >&2
    local WHEEL_FILE
    WHEEL_FILE=$(ls "${WHEEL_OUT_DIR}"/mat3ra_notebooks_utils-*.whl | tail -1)
    cp "${WHEEL_FILE}" "${DEST_DIR}/"
    echo "${DEST_DIR}/$(basename "${WHEEL_FILE}")"
}

# Registers the mat3ra wheel in pyodide-lock.json so Pyodide can resolve and load it
# by name. The "imports" field maps the top-level "mat3ra" namespace to this package,
# which is what triggers loading when "import mat3ra.*" is called.
patch_pyodide_lock() {
    local LOCK_FILE=$1
    local WHEEL_PATH=$2
    local WHEEL_FILE
    WHEEL_FILE=$(basename "${WHEEL_PATH}")
    local SHA256
    SHA256=$(shasum -a 256 "${WHEEL_PATH}" | awk '{print $1}')
    python3 - <<EOF
import json
with open('${LOCK_FILE}', 'r') as f:
    lock = json.load(f)
lock['packages']['mat3ra'] = {
    "name": "mat3ra",
    "version": "1.0.0",
    "file_name": "${WHEEL_FILE}",
    "install_dir": "site",
    "sha256": "${SHA256}",
    "package_type": "package",
    "imports": ["mat3ra"],
    "depends": ["pyyaml"],
    "unvendored_tests": True,
    "shared_library": False,
}
with open('${LOCK_FILE}', 'w') as f:
    json.dump(lock, f, indent=2)
EOF
    echo "Patched ${LOCK_FILE} with mat3ra entry (sha256: ${SHA256})."
}

# Adds a missing dependency to an existing package entry in pyodide-lock.json.
# Needed when the upstream lock file omits a dependency that is required at runtime
# but not declared (e.g. pyyaml missing from micropip.depends).
patch_pyodide_lock_depends() {
    local LOCK_FILE=$1
    local PACKAGE_NAME=$2
    local DEPENDENCY=$3
    python3 - <<EOF
import json
with open('${LOCK_FILE}', 'r') as f:
    lock = json.load(f)
depends = lock['packages']['${PACKAGE_NAME}']['depends']
if '${DEPENDENCY}' not in depends:
    depends.append('${DEPENDENCY}')
with open('${LOCK_FILE}', 'w') as f:
    json.dump(lock, f, indent=2)
EOF
    echo "Added '${DEPENDENCY}' to ${PACKAGE_NAME}.depends in ${LOCK_FILE}."
}

# Adds "mat3ra" to the list of packages to load in JupyterLite's pyodide-kernel-extension config,
# so that "import mat3ra.*" works in notebooks without an explicit micropip.install call.
patch_jupyter_lite_packages() {
    local JUPYTER_LITE_JSON=$1
    python3 - <<EOF
import json
with open('${JUPYTER_LITE_JSON}', 'r') as f:
    config = json.load(f)
settings = config['jupyter-config-data'].setdefault('litePluginSettings', {})
kernel = settings.setdefault('@jupyterlite/pyodide-kernel-extension:kernel', {})
options = kernel.setdefault('loadPyodideOptions', {})
packages = options.setdefault('packages', [])
if 'mat3ra' not in packages:
    packages.append('mat3ra')
with open('${JUPYTER_LITE_JSON}', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    echo "Patched ${JUPYTER_LITE_JSON} with mat3ra in loadPyodideOptions.packages."
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
