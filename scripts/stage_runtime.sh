#!/bin/bash
# Prepares runtime assets used by the JupyterLite build.
# Downloads/caches Pyodide and optionally collects dependency wheels from content config.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
CONTENT_DIR="${CONTENT_DIR:-content}"
PYODIDE_VERSION="${PYODIDE_VERSION:-0.24.1}"
PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"
PYODIDE_LOCK_FILE="${PYODIDE_LOCK_FILE:-${PYODIDE_LOCAL_DIR}/pyodide-lock.json}"
IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION:-8.31.0}"
RUNTIME_PINNED_SPECS="${RUNTIME_PINNED_SPECS:-ipython==${IPYTHON_PINNED_VERSION}}"
COLLECT_WHEELS="${COLLECT_WHEELS:-0}"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1

download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"

if [[ "${COLLECT_WHEELS}" == "1" ]]; then
    collect_config_dependency_wheels \
      "${CONTENT_DIR}/config.yml" \
      "${CONTENT_DIR}/packages" \
      "${PYODIDE_LOCK_FILE}" \
      "${RUNTIME_PINNED_SPECS}"
fi
