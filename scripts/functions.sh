#!/bin/bash

ensure_python_version_installed() {
    local PYTHON_VERSION=$1
    if ! pyenv versions | grep -q $PYTHON_VERSION; then
        echo "Python $PYTHON_VERSION not found. Installing..."
        pyenv install $PYTHON_VERSION
    fi
    pyenv local $PYTHON_VERSION
}

ensure_node_version_installed() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    if ! nvm list | grep -q $NODE_VERSION; then
        echo "Node.js $NODE_VERSION not found. Installing..."
        nvm install $NODE_VERSION
    fi
    nvm use $NODE_VERSION
}

create_virtualenv() {
    local VENV_NAME=$1
    if [ ! -d ${VENV_NAME} ]; then
        python -m venv ${VENV_NAME}
    fi
    source ${VENV_NAME}/bin/activate
}

create_extension_template() {
    local COOKIECUTTER_OPTIONS=("$@")
    local COOKIECUTTER_TEMPLATE_PATH="$HOME/.cookiecutters/extension-cookiecutter-ts"
    pip install cookiecutter jupyterlab==4 jupyterlite-core
    # Use cookiecutter with the template path if it exists, otherwise use the URL
    if [ ! -d "$COOKIECUTTER_TEMPLATE_PATH" ]; then
        cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
        echo "Created extension using cookiecutter template."
    else
        # COOKIECUTTER_OPTIONS[0]="$COOKIECUTTER_TEMPLATE_PATH"
        cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
        echo "Created extension using cached cookiecutter template."
    fi
}

build_extension() {
    local EXTENSION_NAME=$1
    local PACKAGE_ROOT_PATH=$2
    # Following https://github.com/jupyterlite/jupyterlite/blob/dee7a211ec0fc3f18f4d39b1b9fce9b508d4d0df/docs/howto/configure/advanced/iframe.md
    # Our extension is treated as a separate package in ./extensions/src directory
    # Copy the extension source file that we changed to the cookiecutter template in ./extensions/dist directory
    # It places the source file in the dist/EXTENSION_NAME/src file that will be used for the build
    SRC_FILE="${PACKAGE_ROOT_PATH}/extensions/src/${EXTENSION_NAME}/index.ts"
    DEST_FILE="${PACKAGE_ROOT_PATH}/extensions/dist/${EXTENSION_NAME}/src/index.ts"

    if [ -f "$SRC_FILE" ] && [ -d "$DEST_FILE" ]; then
        cp "$SRC_FILE" "$DEST_FILE"
    else
        echo "Source file or destination directory not found. Skipping copy."
    fi

    cd "${PACKAGE_ROOT_PATH}/extensions/src/${EXTENSION_NAME}" || exit 1

    # To avoid 'Intl' has no exported member named 'ResolvedRelativeTimeFormatOptions'.
    # node_modules/@jupyterlab/coreutils/lib/time.d.ts:5:28
    sed -i.bak '/"compilerOptions": {/a\'$'\n''  "skipLibCheck": true,'$'\n' tsconfig.json

    # The extension is treated here as a separate package so it requires to have a yarn.lock file
    touch yarn.lock
    pip install -ve .

    jupyter labextension develop --overwrite .

    # Install dependencies
    jlpm add @jupyterlab/application @jupyterlab/notebook @mat3ra/esse

    # Build the extension
    jlpm run build
    cd - || exit 1
}

add_line_to_file_if_not_present() {
    local LINE=$1
    local FILE=$2
    grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}

cleanup() {
    local EXTENSION_NAME=$1
    rm -rf ${PACKAGE_ROOT_PATH}/dist/extensions/${EXTENSION_NAME}
    rm -rf ${PACKAGE_ROOT_PATH}/extensions/dist/${EXTENSION_NAME}
}
