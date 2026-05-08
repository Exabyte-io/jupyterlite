#!/bin/bash
# Syncs notebook content and package manifests into jupyterlite/content.
# Prefers local ../api-examples source, with git clone/pull fallback.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
TMP_DIR="${TMP_DIR:-tmp}"
CONTENT_DIR="${CONTENT_DIR:-content}"
REPO_NAME="${REPO_NAME:-api-examples}"
BRANCH_NAME="${BRANCH_NAME:-feature/SOF-7894}"
AX_SOURCE_DIR="${AX_SOURCE_DIR:-${PACKAGE_ROOT_PATH}/../api-examples}"

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

# Remove known dangling links from api-examples content.
if [[ -L "${CONTENT_DIR}/made/uploads/C(001)-Ni(111)-Interface.json" ]]; then
    rm -f "${CONTENT_DIR}/made/uploads/C(001)-Ni(111)-Interface.json"
fi

for readme_file in ${CONTENT_DIR}/README.*; do
    [[ -f "${readme_file}" ]] || continue
    perl -i.bak -pe "s{examples/}{api/}g; s{examples\\\\/}{api\\\\/}g" "${readme_file}"
    rm -f "${readme_file}.bak"
done
