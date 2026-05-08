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
[[ "${INSTALL}" == "1" ]] && RUN_INSTALL=true
[[ "${UPDATE_CONTENT}" == "1" ]] && RUN_UPDATE_CONTENT=true
[[ "${BUILD}" == "1" ]] && RUN_BUILD=true

if ${RUN_INSTALL}; then
    bash "${THIS_SCRIPT_DIR_PATH}/install.sh" || exit 1
fi

# Activate virtualenv if it exists
VENV_PATH="${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}/bin/activate"
if [[ -f "${VENV_PATH}" ]]; then
    source "${VENV_PATH}"
    echo "Activated virtualenv: ${VENV_PATH}"
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
    mkdir -p "${CONTENT_DIR}/experiments"
    cp -R "${RESOLVED_CONTENT_DIR}/other/experiments/jupyterlite" "${CONTENT_DIR}/experiments/jupyterlite"
    cp -R "${RESOLVED_CONTENT_DIR}"/{utils,config.yml,README*} "${CONTENT_DIR}/"

    # Copy packages: first from api-examples (Pyodide-compiled), then from assets (PyPI)
    mkdir -p "${CONTENT_DIR}/packages"
    if [[ -d "${RESOLVED_CONTENT_DIR}/packages" ]]; then
        cp "${RESOLVED_CONTENT_DIR}/packages"/*.whl "${CONTENT_DIR}/packages/" 2>/dev/null || true
    fi
    cp assets/packages/*.whl "${CONTENT_DIR}/packages/" 2>/dev/null || true

    for readme_file in ${CONTENT_DIR}/README.*; do
        [[ -f "${readme_file}" ]] || continue
        perl -i.bak -pe "s{examples/}{api/}g; s{examples\\\\/}{api\\\\/}g" "${readme_file}"
        rm -f "${readme_file}.bak"
    done
fi

if ! ${RUN_BUILD}; then
    exit 0
fi

cd "${PACKAGE_ROOT_PATH}" || exit 1

# Copy Pyodide assets to dist
mkdir -p dist/pyodide
cp -R "${PYODIDE_ASSETS_DIR}"/* dist/pyodide/

PIPLITE_ARGS=()
for whl in "${CONTENT_DIR}/packages"/*.whl; do
    [[ -f "${whl}" ]] && PIPLITE_ARGS+=(--piplite-wheels "${whl}")
done

run_jupyterlite_build --contents "${CONTENT_DIR}" --output-dir dist "${PIPLITE_ARGS[@]}" || exit 1
find dist/extensions/@jupyterlite/pyodide-kernel-extension/static -name "*.js" \
    | xargs rg -l "install\(\['ipython'\]" \
    | xargs perl -i -pe "s/install\(\['ipython'\]/install(\['ipython==${IPYTHON_PINNED_VERSION}'\]/g"

patch_pyodide_url "dist/jupyter-lite.json" "./pyodide/pyodide.js"
patch_pyodide_startup_packages "dist/jupyter-lite.json"

exit 0
