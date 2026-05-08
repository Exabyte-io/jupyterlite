#!/bin/bash
# Download and cache a fixed Pyodide release into dist.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
PYODIDE_VERSION="${PYODIDE_VERSION:-0.24.1}"
PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1
download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"
