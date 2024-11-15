#!/bin/bash
# This script creates a JupyterLab extension using the cookiecutter template
# and updates the requirements.txt file to make it installable in the current
# JupyterLab environment.

PYTHON_VERSION="3.10.12"
NODE_VERSION="18"
EXTENSION_NAME="data_bridge"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="${THIS_SCRIPT_DIR_PATH}/../"
BUILD_DIR_PATH="${PACKAGE_ROOT_PATH}/extensions/dist"
EXTENSION_PATH="./extensions/dist/${EXTENSION_NAME}"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh


# Ensure Python and Node.js versions are installed
ensure_python_version_installed ${PYTHON_VERSION}
ensure_node_version_installed ${NODE_VERSION}
create_virtualenv "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}"

# Build extension using cookiecutter template and sources
mkdir -p "${BUILD_DIR_PATH}" && cd "${BUILD_DIR_PATH}" || exit 1
create_extension_template "${COOKIECUTTER_OPTIONS[@]}"
build_extension ${EXTENSION_NAME} "${PACKAGE_ROOT_PATH}"
#
## Build JupiterLite with extension
cd "${PACKAGE_ROOT_PATH}" || exit 1
# We follow the steps from https://github.com/jupyterlite/jupyterlite/blob/dee7a211ec0fc3f18f4d39b1b9fce9b508d4d0df/docs/howto/configure/advanced/iframe.md
# And installing extension and building the JupyterLite server as guided here, during the setup
add_line_to_file_if_not_present "${EXTENSION_PATH}" "requirements.txt"
python -m pip install -r requirements.txt
jupyter lite build --contents content --output-dir dist

# Exit with zero (for GH workflow)
exit 0
