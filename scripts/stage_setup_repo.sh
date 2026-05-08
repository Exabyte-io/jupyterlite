#!/bin/bash
# Sets up local Python tooling for JupyterLite development.
# Installs pinned packaging tools and project requirements in the active environment.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
REQUIREMENTS_FILENAME="${PACKAGE_ROOT_PATH}/dependencies/requirements.txt"

PIP_VERSION="${PIP_VERSION:-24.3.1}"
SETUPTOOLS_VERSION="${SETUPTOOLS_VERSION:-75.8.0}"
WHEEL_VERSION="${WHEEL_VERSION:-0.37.1}"
BUILD_VERSION="${BUILD_VERSION:-0.7.0}"
TWINE_VERSION="${TWINE_VERSION:-3.7.1}"

cd "${PACKAGE_ROOT_PATH}" || exit 1

pip install --upgrade \
  pip=="${PIP_VERSION}" \
  setuptools=="${SETUPTOOLS_VERSION}" \
  wheel=="${WHEEL_VERSION}" \
  build=="${BUILD_VERSION}" \
  twine=="${TWINE_VERSION}" || exit 1

python -m pip install -r "${REQUIREMENTS_FILENAME}" || exit 1
pip list
