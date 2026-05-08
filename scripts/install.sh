#!/bin/bash
# Bootstraps local dev toolchain versions (Python, Node, and venv).
# This prepares the full local environment for JupyterLite development.

PYTHON_VERSION="3.10.12"
NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
REQUIREMENTS_FILENAME="${PACKAGE_ROOT_PATH}/dependencies/requirements.txt"

PIP_VERSION="${PIP_VERSION:-24.3.1}"
SETUPTOOLS_VERSION="${SETUPTOOLS_VERSION:-75.8.0}"
WHEEL_VERSION="${WHEEL_VERSION:-0.37.1}"
BUILD_VERSION="${BUILD_VERSION:-0.7.0}"
TWINE_VERSION="${TWINE_VERSION:-3.7.1}"

source "${THIS_SCRIPT_DIR_PATH}"/cookiecutter_setup.sh
source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

# Ensure Python and Node.js versions are installed
ensure_python_version_installed ${PYTHON_VERSION}
ensure_node_version_installed ${NODE_VERSION}
create_virtualenv "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}"

cd "${PACKAGE_ROOT_PATH}" || exit 1
pip install --upgrade \
  pip=="${PIP_VERSION}" \
  setuptools=="${SETUPTOOLS_VERSION}" \
  wheel=="${WHEEL_VERSION}" \
  build=="${BUILD_VERSION}" \
  twine=="${TWINE_VERSION}" || exit 1
python -m pip install -r "${REQUIREMENTS_FILENAME}" || exit 1
