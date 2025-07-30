#!/bin/bash
set -e  # Exit on any error
trap 'echo "❌ Build failed at line $LINENO with exit code $?" >&2' ERR
# PYTHON_VERSION="3.10.12"
# NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
REQUIREMENTS_FILENAME="dependencies/requirements.txt"
TMP_DIR="tmp"
CONTENT_DIR="content"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

## Build JupyterLite with extension(s)
echo "🚀 Starting build process..."
echo "📁 Changing to package root: ${PACKAGE_ROOT_PATH}"
cd "${PACKAGE_ROOT_PATH}" || exit 1

if [[ -n ${INSTALL} ]]; then
    echo "=== Installing Python dependencies ==="
    python -m pip install -r ${REQUIREMENTS_FILENAME}
    
    echo "=== Checking data-bridge installation ==="
    python -m pip list | grep -i bridge || echo "❌ No bridge extension found"
    python -c "import data_bridge; print(f'✅ data_bridge found at: {data_bridge.__file__}')" || echo "❌ data_bridge import failed"
    
    echo "=== Checking JupyterLab extensions ==="
    python -m jupyter labextension list || echo "❌ labextension list failed"
fi

# Update the content dir to latest commit
if [[ -n ${UPDATE_CONTENT} ]]; then
    echo "📥 Updating content from repository..."
    mkdir -p ${TMP_DIR} && cd ${TMP_DIR} || exit 1
    REPO_NAME="api-examples"
    BRANCH_NAME="feature/SOF-7686" # "main"
    BRANCH_NAME_FALLBACK="feature/SOF-7686" # "dev"

    # Clone repository if it doesn't exist
    [[ ! -e "${REPO_NAME}" ]] && git clone https://github.com/Exabyte-io/${REPO_NAME}.git
    cd ${REPO_NAME} || exit 1
    git checkout ${BRANCH_NAME} || git checkout ${BRANCH_NAME_FALLBACK} && git pull

    # Install git-lfs and pull LFS files
    git lfs install && git lfs pull
    git --no-pager log --decorate=short --pretty=oneline -n1
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
    # Copy other required files
    cp -r ${RESOLVED_CONTENT_DIR}/{packages,utils,config.yml,README*} ${CONTENT_DIR}/
    # Update path references in README* files (only text files, skip .ipynb)
    find ${CONTENT_DIR} -name "README*" -type f ! -name "*.ipynb" -exec perl -pi -e 's/examples\//api\//g' {} \;
fi

if [[ -n ${BUILD} ]]; then
    echo "🏗️  Building JupyterLite..."
    echo "=== Building JupyterLite ==="
    jupyter lite build --contents ${CONTENT_DIR} --output-dir dist
    
    echo "=== Checking built extensions ==="
    ls -la dist/extensions/ 2>/dev/null | head -20 || echo "❌ No extensions directory found"
    find dist/ -name "*data*bridge*" -o -name "*bridge*" 2>/dev/null | head -10 || echo "❌ No data-bridge files found in dist"
fi

# Exit with zero (for GH workflow)
exit 0
