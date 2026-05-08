#!/bin/bash
# Download/copy dependency wheels from config into content/packages.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
CONTENT_DIR="${CONTENT_DIR:-content}"
PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"
PYODIDE_LOCK_FILE="${PYODIDE_LOCK_FILE:-${PYODIDE_LOCAL_DIR}/pyodide-lock.json}"
IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION:-8.31.0}"
RUNTIME_PINNED_SPECS="${RUNTIME_PINNED_SPECS:-ipython==${IPYTHON_PINNED_VERSION}}"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1
collect_config_dependency_wheels \
  "${CONTENT_DIR}/config.yml" \
  "${CONTENT_DIR}/packages" \
  "${PYODIDE_LOCK_FILE}" \
  "${RUNTIME_PINNED_SPECS}"
