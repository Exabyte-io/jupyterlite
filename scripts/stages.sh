#!/bin/bash
# Internal stage runner for JupyterLite build pipeline.
# Usage: bash scripts/stages.sh <setup|runtime|content|build|serve>

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

run_jupyterlite_build() {
    if command -v jupyter >/dev/null 2>&1; then
        jupyter lite build "$@"
        return
    fi
    python -m jupyterlite build "$@"
}

run_setup() {
    local REQUIREMENTS_FILENAME="${PACKAGE_ROOT_PATH}/dependencies/requirements.txt"
    local PIP_VERSION="${PIP_VERSION:-24.3.1}"
    local SETUPTOOLS_VERSION="${SETUPTOOLS_VERSION:-75.8.0}"
    local WHEEL_VERSION="${WHEEL_VERSION:-0.37.1}"
    local BUILD_VERSION="${BUILD_VERSION:-0.7.0}"
    local TWINE_VERSION="${TWINE_VERSION:-3.7.1}"

    cd "${PACKAGE_ROOT_PATH}" || exit 1
    pip install --upgrade \
      pip=="${PIP_VERSION}" \
      setuptools=="${SETUPTOOLS_VERSION}" \
      wheel=="${WHEEL_VERSION}" \
      build=="${BUILD_VERSION}" \
      twine=="${TWINE_VERSION}" || exit 1
    python -m pip install -r "${REQUIREMENTS_FILENAME}" || exit 1
    pip list
}

run_runtime() {
    local CONTENT_DIR="${CONTENT_DIR:-content}"
    local PYODIDE_VERSION="${PYODIDE_VERSION:-0.24.1}"
    local PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"
    local PYODIDE_LOCK_FILE="${PYODIDE_LOCK_FILE:-${PYODIDE_LOCAL_DIR}/pyodide-lock.json}"
    local IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION:-8.31.0}"
    local RUNTIME_PINNED_SPECS="${RUNTIME_PINNED_SPECS:-ipython==${IPYTHON_PINNED_VERSION}}"
    local COLLECT_WHEELS="${COLLECT_WHEELS:-0}"

    source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

    cd "${PACKAGE_ROOT_PATH}" || exit 1
    download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"
    if [[ "${COLLECT_WHEELS}" == "1" ]]; then
        collect_config_dependency_wheels \
          "${CONTENT_DIR}/config.yml" \
          "${CONTENT_DIR}/packages" \
          "${PYODIDE_LOCK_FILE}" \
          "${RUNTIME_PINNED_SPECS}"
    fi
}

run_content() {
    local TMP_DIR="${TMP_DIR:-tmp}"
    local CONTENT_DIR="${CONTENT_DIR:-content}"
    local REPO_NAME="${REPO_NAME:-api-examples}"
    local BRANCH_NAME="${BRANCH_NAME:-feature/SOF-7894}"
    local AX_SOURCE_DIR="${AX_SOURCE_DIR:-${PACKAGE_ROOT_PATH}/../api-examples}"
    local RESOLVED_CONTENT_DIR=""

    cd "${PACKAGE_ROOT_PATH}" || exit 1
    mkdir -p "${TMP_DIR}" && cd "${TMP_DIR}" || exit 1

    if [[ -d "${AX_SOURCE_DIR}" ]]; then
        echo "Using local api-examples source: ${AX_SOURCE_DIR}"
        RESOLVED_CONTENT_DIR="${AX_SOURCE_DIR}"
    else
        if [[ ! -e "${REPO_NAME}" ]]; then
            git clone "https://github.com/Exabyte-io/${REPO_NAME}.git" || exit 1
        fi
        cd "${REPO_NAME}" || exit 1
        git checkout "${BRANCH_NAME}" || exit 1
        git pull || exit 1
        git lfs install && git lfs pull || exit 1
        git --no-pager log --decorate=short --pretty=oneline -n1
        cd - || exit 1
        rm -rf "${REPO_NAME}-resolved"
        cp -rL "${REPO_NAME}" "${REPO_NAME}-resolved"
        RESOLVED_CONTENT_DIR="${PACKAGE_ROOT_PATH}/${TMP_DIR}/${REPO_NAME}-resolved"
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
}

run_build() {
    local CONTENT_DIR="${CONTENT_DIR:-content}"
    local PYODIDE_VERSION="${PYODIDE_VERSION:-0.24.1}"
    local PYODIDE_LOCAL_DIR="${PYODIDE_LOCAL_DIR:-dist/pyodide}"
    local PYODIDE_LOCAL_URL="${PYODIDE_LOCAL_URL:-./pyodide/pyodide.js}"
    local IPYTHON_PINNED_VERSION="${IPYTHON_PINNED_VERSION:-8.31.0}"
    local PIPLITE_ARGS=()

    source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

    cd "${PACKAGE_ROOT_PATH}" || exit 1
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
}

run_serve() {
    local PORT="${PORT:-8000}"
    local SERVE_DIR="${SERVE_DIR:-./dist}"
    cd "${PACKAGE_ROOT_PATH}" || exit 1
    python "${THIS_SCRIPT_DIR_PATH}/serve.py" "${PORT}" "${SERVE_DIR}"
}

case "$1" in
    setup) run_setup ;;
    runtime) run_runtime ;;
    content) run_content ;;
    build) run_build ;;
    serve) run_serve ;;
    *)
        echo "Usage: $0 <setup|runtime|content|build|serve>"
        exit 1
        ;;
esac
