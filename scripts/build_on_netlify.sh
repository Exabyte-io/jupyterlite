#!/bin/bash
# Netlify-focused entrypoint that prepares venv and runs build.sh.
# Keeps content sync and build behavior aligned with local scripts.

# NOTE: a separate script is required for the "data_bridge" extension
# to be properly linked into the JupyterLite build process on Netlify.
# TODO: figure out how to do it in a single script.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
PYTHON_VERSION="${PYTHON_VERSION:-3.10.12}"
NODE_VERSION="${NODE_VERSION:-18}"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

echo "Python version: $(python --version), and $PYTHON_VERSION"
echo "Node.js version: $(node --version), and $NODE_VERSION"
echo "Creating virtual environment"

create_virtualenv "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}"

INSTALL=0 UPDATE_CONTENT=1 BUILD=1 DOWNLOAD_PACKAGES=1 bash "${THIS_SCRIPT_DIR_PATH}"/build.sh
