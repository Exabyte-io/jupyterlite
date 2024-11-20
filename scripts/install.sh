#!/bin/bash

PYTHON_VERSION="3.10.12"
NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

source "${THIS_SCRIPT_DIR_PATH}"/cookiecutter_setup.sh
source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

# Ensure Python and Node.js versions are installed
ensure_python_version_installed ${PYTHON_VERSION}
ensure_node_version_installed ${NODE_VERSION}
create_virtualenv "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}"
