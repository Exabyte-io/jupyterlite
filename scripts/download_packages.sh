#!/bin/bash
# Download/copy dependency wheels from requirements.txt into assets/packages.
# Run this manually after updating requirements.txt, then commit assets/packages to the repo.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"

source "${THIS_SCRIPT_DIR_PATH}/functions.sh"

# Activate virtualenv
source "${PACKAGE_ROOT_PATH}/.venv-${PYTHON_VERSION}/bin/activate"

cd "${PACKAGE_ROOT_PATH}" || exit 1

REQUIREMENTS_FILE="assets/packages/requirements.txt"
PACKAGES_DIR="assets/packages"

if [[ ! -f "${REQUIREMENTS_FILE}" ]]; then
    echo "Requirements file not found: ${REQUIREMENTS_FILE}"
    exit 1
fi

echo "Downloading wheels from ${REQUIREMENTS_FILE} to ${PACKAGES_DIR}..."
pip download --only-binary=:all: --dest "${PACKAGES_DIR}" -r "${REQUIREMENTS_FILE}"

echo "Keeping only pure-python and emscripten wheels..."
cd "${PACKAGES_DIR}" || exit 1
kept=0
removed=0
for whl in *.whl 2>/dev/null; do
    [[ -f "$whl" ]] || continue
    if [[ "$whl" == *"-py3-none-any.whl" ]] || [[ "$whl" == *"-py2.py3-none-any.whl" ]] || [[ "$whl" == *"emscripten"* ]]; then
        echo "  Kept: $whl"
        ((kept++))
    else
        echo "  Removed: $whl (platform-specific)"
        rm "$whl"
        ((removed++))
    fi
done

echo ""
echo "Summary: kept $kept wheels, removed $removed platform-specific wheels."
echo "Pure-python wheels in ${PACKAGES_DIR}:"
ls -1 *.whl 2>/dev/null | wc -l
echo "wheels ready."
