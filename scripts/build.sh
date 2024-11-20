#!/bin/bash
PYTHON_VERSION="3.10.12"
NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
BUILD_DIR_PATH="${PACKAGE_ROOT_PATH}/extensions/dist"
REQUIREMENTS_FILENAME="requirements.txt"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

## Build JupyterLite with extension(s)
cd "${PACKAGE_ROOT_PATH}" || exit 1

[[ -n ${INSTALL} ]] && python -m pip install -r ${REQUIREMENTS_FILENAME}
[[ -n ${COPY} ]] && cp -rL content content-resolved
[[ -n ${BUILD} ]] && jupyter lite build --contents content --output-dir dist

# Exit with zero (for GH workflow)
exit 0
