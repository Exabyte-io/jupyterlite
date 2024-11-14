#!/bin/bash
# This script rebuilds the JupyterLab extension and starts the JupyterLite server
# Meant to automate the process during development

EXTENSION_NAME="data_bridge"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="${THIS_SCRIPT_DIR_PATH}/../"
BUILD_DIR_PATH="${PACKAGE_ROOT_PATH}/extensions/dist"

# Remove JupyterLite dist folder containing built extension
rm -rf "${PACKAGE_ROOT_PATH}"/dist/extensions/${EXTENSION_NAME}

# Rebuild the extension
cd "${BUILD_DIR_PATH}"/${EXTENSION_NAME} || exit 1
jlpm run build
cd - || exit 1

npm run build && npm run start -p=8000
