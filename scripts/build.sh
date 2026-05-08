#!/bin/bash
# Orchestrates JupyterLite build stages with toggle flags.
# INSTALL=1 runs environment setup, UPDATE_CONTENT=1 syncs AX content, BUILD=1 builds dist.

# PYTHON_VERSION="3.10.12"
# NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

## Build JupyterLite with extension(s)
cd "${PACKAGE_ROOT_PATH}" || exit 1

RUN_INSTALL=false
RUN_UPDATE_CONTENT=false
RUN_BUILD=false
[[ "${INSTALL}" == "1" ]] && RUN_INSTALL=true
[[ "${UPDATE_CONTENT}" == "1" ]] && RUN_UPDATE_CONTENT=true
[[ "${BUILD}" == "1" ]] && RUN_BUILD=true

if ${RUN_INSTALL}; then
    bash "${THIS_SCRIPT_DIR_PATH}/stage_setup_repo.sh" || exit 1
fi

if ${RUN_UPDATE_CONTENT}; then
    bash "${THIS_SCRIPT_DIR_PATH}/stage_update_content.sh" || exit 1
fi

if ! ${RUN_BUILD}; then
    exit 0
fi

if ${RUN_INSTALL}; then
    COLLECT_WHEELS=1 bash "${THIS_SCRIPT_DIR_PATH}/stage_runtime.sh" || exit 1
else
    COLLECT_WHEELS=0 bash "${THIS_SCRIPT_DIR_PATH}/stage_runtime.sh" || exit 1
fi

bash "${THIS_SCRIPT_DIR_PATH}/stage_build_dist.sh" || exit 1

# Exit with zero (for GH workflow)
exit 0
