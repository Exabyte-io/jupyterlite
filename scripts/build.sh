#!/bin/bash
# Build JupyterLite from local content and wheel cache.
# INSTALL=1 runs scripts/install.sh, UPDATE_CONTENT=1 syncs AX content, BUILD=1 builds dist.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
TMP_DIR="tmp"
CONTENT_DIR="content"
AX_REPO_NAME="api-examples"
AX_BRANCH_NAME="feature/SOF-7894"
AX_SOURCE_DIR="${PACKAGE_ROOT_PATH}/../api-examples"
PYODIDE_VERSION="0.24.1"
PYODIDE_LOCAL_DIR="dist/pyodide"
PYODIDE_LOCAL_URL="./pyodide/pyodide.js"
IPYTHON_PINNED_VERSION="8.31.0"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

cd "${PACKAGE_ROOT_PATH}" || exit 1

run_jupyterlite_build() {
    if command -v jupyter >/dev/null 2>&1; then
        jupyter lite build "$@"
        return
    fi
    python -m jupyterlite build "$@"
}

RUN_INSTALL=false
RUN_UPDATE_CONTENT=false
RUN_BUILD=false
RUN_DOWNLOAD_PACKAGES=false
[[ "${INSTALL}" == "1" ]] && RUN_INSTALL=true
[[ "${UPDATE_CONTENT}" == "1" ]] && RUN_UPDATE_CONTENT=true
[[ "${BUILD}" == "1" ]] && RUN_BUILD=true
[[ "${DOWNLOAD_PACKAGES}" == "1" ]] && RUN_DOWNLOAD_PACKAGES=true

if ${RUN_INSTALL}; then
    RUN_DOWNLOAD_PACKAGES=true
fi

if ${RUN_INSTALL}; then
    bash "${THIS_SCRIPT_DIR_PATH}/install.sh" || exit 1
fi

if ${RUN_UPDATE_CONTENT}; then
    mkdir -p "${TMP_DIR}" && cd "${TMP_DIR}" || exit 1
    if [[ -d "${AX_SOURCE_DIR}" ]]; then
        echo "Using local api-examples source: ${AX_SOURCE_DIR}"
        RESOLVED_CONTENT_DIR="${AX_SOURCE_DIR}"
    else
        if [[ ! -e "${AX_REPO_NAME}" ]]; then
            git clone "https://github.com/Exabyte-io/${AX_REPO_NAME}.git" || exit 1
        fi
        cd "${AX_REPO_NAME}" || exit 1
        git checkout "${AX_BRANCH_NAME}" || exit 1
        git pull || exit 1
        git lfs install && git lfs pull || exit 1
        git --no-pager log --decorate=short --pretty=oneline -n1
        cd - || exit 1
        rm -rf "${AX_REPO_NAME}-resolved"
        cp -rL "${AX_REPO_NAME}" "${AX_REPO_NAME}-resolved"
        RESOLVED_CONTENT_DIR="${PACKAGE_ROOT_PATH}/${TMP_DIR}/${AX_REPO_NAME}-resolved"
    fi

    cd "${PACKAGE_ROOT_PATH}" || exit 1
    rm -rf "${CONTENT_DIR}" && mkdir -p "${CONTENT_DIR}"
    cp -R "${RESOLVED_CONTENT_DIR}/examples" "${CONTENT_DIR}/api"
    cp -R "${RESOLVED_CONTENT_DIR}/other/materials_designer" "${CONTENT_DIR}/made"
    cp -R "${RESOLVED_CONTENT_DIR}/other/experiments/jupyterlite" "${CONTENT_DIR}/experiments"
    cp -R "${RESOLVED_CONTENT_DIR}"/{packages,utils,config.yml,README*} "${CONTENT_DIR}/"

    if [[ -L "${CONTENT_DIR}/made/uploads/C(001)-Ni(111)-Interface.json" ]]; then
        rm -f "${CONTENT_DIR}/made/uploads/C(001)-Ni(111)-Interface.json"
    fi

    for readme_file in ${CONTENT_DIR}/README.*; do
        [[ -f "${readme_file}" ]] || continue
        perl -i.bak -pe "s{examples/}{api/}g; s{examples\\\\/}{api\\\\/}g" "${readme_file}"
        rm -f "${readme_file}.bak"
    done
fi

if ! ${RUN_BUILD}; then
    exit 0
fi

PYODIDE_VERSION="${PYODIDE_VERSION}" \
PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR}" \
bash "${THIS_SCRIPT_DIR_PATH}/download_pyodide.sh" || exit 1

if ${RUN_DOWNLOAD_PACKAGES}; then
    CONTENT_DIR="${CONTENT_DIR}" \
    PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR}" \
    IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION}" \
    bash "${THIS_SCRIPT_DIR_PATH}/download_packages.sh" || exit 1
fi

cd "${PACKAGE_ROOT_PATH}" || exit 1
PIPLITE_ARGS=()
for whl in "${CONTENT_DIR}/packages"/*.whl; do
    [[ -f "${whl}" ]] && PIPLITE_ARGS+=(--piplite-wheels "${whl}")
done

run_jupyterlite_build --contents "${CONTENT_DIR}" --output-dir dist "${PIPLITE_ARGS[@]}" || exit 1
find dist/extensions/@jupyterlite/pyodide-kernel-extension/static -name "*.js" \
    | xargs rg -l "install\(\['ipython'\]" \
    | xargs perl -i -pe "s/install\(\['ipython'\]/install(\['ipython==${IPYTHON_PINNED_VERSION}'\]/g"

download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"
patch_pyodide_url "dist/jupyter-lite.json" "${PYODIDE_LOCAL_URL}"
patch_pyodide_startup_packages "dist/jupyter-lite.json"

exit 0
