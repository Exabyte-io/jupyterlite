#!/bin/bash
# Builds the JupyterLite dist bundle from prepared content.
# Registers local wheels for piplite and patches Pyodide kernel runtime settings.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
CONTENT_DIR="${CONTENT_DIR:-content}"
PYODIDE_VERSION="${PYODIDE_VERSION:-0.24.1}"
PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"
PYODIDE_LOCAL_URL="${PYODIDE_LOCAL_URL:-./pyodide/pyodide.js}"
IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION:-8.31.0}"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1

PIPLITE_ARGS=()
for whl in "${CONTENT_DIR}/packages"/*.whl; do
    [[ -f "${whl}" ]] && PIPLITE_ARGS+=(--piplite-wheels "${whl}")
done

jupyter lite build --contents "${CONTENT_DIR}" --output-dir dist "${PIPLITE_ARGS[@]}" || exit 1

find dist/extensions/@jupyterlite/pyodide-kernel-extension/static -name "*.js" \
    | xargs grep -l "install(\['ipython'\]" \
    | xargs perl -i -pe "s/install\(\['ipython'\]/install(\['ipython==${IPYTHON_PINNED_VERSION}'\]/g"

download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"
patch_pyodide_url "dist/jupyter-lite.json" "${PYODIDE_LOCAL_URL}"
patch_pyodide_startup_packages "dist/jupyter-lite.json"
