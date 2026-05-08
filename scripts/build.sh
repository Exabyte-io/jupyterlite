#!/bin/bash
# PYTHON_VERSION="3.10.12"
# NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
REQUIREMENTS_FILENAME="dependencies/requirements.txt"
TMP_DIR="tmp"
CONTENT_DIR="content"
WHEELS_DIR="tmp/piplite-wheels"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

## Build JupyterLite with extension(s)
cd "${PACKAGE_ROOT_PATH}" || exit 1

export PIP_VERSION=24.3.1
export SETUPTOOLS_VERSION=75.8.0
export WHEEL_VERSION=0.37.1
export BUILD_VERSION=0.7.0
export TWINE_VERSION=3.7.1

pip install --upgrade \
  pip==$PIP_VERSION \
  setuptools==$SETUPTOOLS_VERSION \
  wheel==$WHEEL_VERSION \
  build==$BUILD_VERSION \
  twine==$TWINE_VERSION || exit 1

if [[ -n ${INSTALL} ]]; then
    python -m pip install -r ${REQUIREMENTS_FILENAME} || exit 1
fi
pip list

# Update the content dir to latest commit
if [[ -n ${UPDATE_CONTENT} ]]; then
    mkdir -p ${TMP_DIR} && cd ${TMP_DIR} || exit 1
    REPO_NAME="api-examples"
    BRANCH_NAME="main"

    # Clone repository if it doesn't exist
    if [[ ! -e "${REPO_NAME}" ]]; then
        echo "Attempting checkout and exiting if unsuccessful"
        git clone https://github.com/Exabyte-io/${REPO_NAME}.git || exit 1
    fi

    # Pull all required files
    cd ${REPO_NAME} || exit 1
    git checkout ${BRANCH_NAME}
    git pull
    # Install git-lfs and pull LFS files
    git lfs install && git lfs pull
    git --no-pager log --decorate=short --pretty=oneline -n1

    # Re-arrange resolved folders
    cd - || exit 1
    # Resolve links inside the ${REPO_NAME}
    rm -rf ${REPO_NAME}-resolved
    cp -rL ${REPO_NAME} ${REPO_NAME}-resolved
    # Sync with the content directory
    cd "${PACKAGE_ROOT_PATH}" || exit 1
    RESOLVED_CONTENT_DIR="tmp/${REPO_NAME}-resolved"
    rm -rf ${CONTENT_DIR} && mkdir -p ${CONTENT_DIR}
    # Copy the notebooks
    cp -r ${RESOLVED_CONTENT_DIR}/examples ${CONTENT_DIR}/api
    cp -r ${RESOLVED_CONTENT_DIR}/other/materials_designer ${CONTENT_DIR}/made
    cp -r ${RESOLVED_CONTENT_DIR}/other/experiments/jupyterlite ${CONTENT_DIR}/experiments
    # Copy other required files
    cp -r ${RESOLVED_CONTENT_DIR}/{packages,utils,config.yml,README*} ${CONTENT_DIR}/
    # Update path references in README*
    sed -i "s/examples\//api\//g" ${CONTENT_DIR}/README.*
fi


if [[ -n ${BUILD} ]]; then
    download_config_packages "${CONTENT_DIR}/config.yml" "${WHEELS_DIR}"

    PIPLITE_ARGS=()
    for whl in "${WHEELS_DIR}"/*.whl "${CONTENT_DIR}/packages"/*.whl; do
        [[ -f "$whl" ]] && PIPLITE_ARGS+=(--piplite-wheels "$whl")
    done
    unpack_preinstalled_wheels "${CONTENT_DIR}/preinstalled" "${WHEELS_DIR}"/*.whl "${CONTENT_DIR}/packages"/*.whl

    jupyter lite build --contents ${CONTENT_DIR} --output-dir dist "${PIPLITE_ARGS[@]}"
    patch_pyodide_startup_packages "${CONTENT_DIR}/config.yml" "dist/pypi/all.json" "dist/jupyter-lite.json"
fi

# Exit with zero (for GH workflow)
exit 0
