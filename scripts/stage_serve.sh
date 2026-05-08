#!/bin/bash
# Serves the built JupyterLite site from dist.
# Configure PORT and SERVE_DIR via environment variables when needed.

THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
PORT="${PORT:-8000}"
SERVE_DIR="${SERVE_DIR:-./dist}"

cd "${PACKAGE_ROOT_PATH}" || exit 1
python "${THIS_SCRIPT_DIR_PATH}/serve.py" "${PORT}" "${SERVE_DIR}"
