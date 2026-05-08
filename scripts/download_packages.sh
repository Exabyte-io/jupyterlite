#!/bin/bash
# Download/copy dependency wheels from config into content/packages.
# Run this manually after updating config.yml, then commit content/packages to the repo.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

# Activate virtualenv
source "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}/bin/activate"

cd "${PACKAGE_ROOT_PATH}" || exit 1
collect_config_dependency_wheels \
  "content/config.yml" \
  "content/packages" \
  "${PYODIDE_ASSETS_DIR}/pyodide-lock.json" \
  "ipython==${IPYTHON_PINNED_VERSION}"
