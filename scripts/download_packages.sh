#!/bin/bash
# Download/copy dependency wheels from config into content/packages.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1
collect_config_dependency_wheels \
  "content/config.yml" \
  "content/packages" \
  "dist/pyodide/pyodide-lock.json" \
  "ipython==${IPYTHON_PINNED_VERSION}"
