#!/bin/bash
# This script creates a JupyterLab extension using the cookiecutter template
# and updates the requirements.txt file to make it installable in the current 
# JupyterLab environment.
# It assumes that pyenv and nvm are installed and configured correctly.

PYTHON_VERSION="3.10"
NODE_VERSION="18"
EXTENSION_NAME="data_bridge"
COOKIECUTTER_TEMPLATE_PATH="$HOME/.cookiecutters/extension-cookiecutter-ts"
GITHUB_TEMPLATE_URL="https://github.com/jupyterlab/extension-cookiecutter-ts"

kind="frontend"
author_name="Mat3ra"
author_email="info@mat3ra.com"
labextension_name=$EXTENSION_NAME
python_name=$EXTENSION_NAME
project_short_description="A JupyterLab extension that allows you to send data between notebook and host page"
has_settings=n
has_binder=n
test=n
repository="https://github.com/exabyte-io/jupyter-lite"

COOKIECUTTER_OPTIONS=(
    "$GITHUB_TEMPLATE_URL"
    "--no-input"
    "kind=$kind"
    "author_name=$author_name"
    "author_email=$author_email"
    "labextension_name=$labextension_name"
    "python_name=$python_name"
    "project_short_description=$project_short_description"
    "has_settings=$has_settings"
    "has_binder=$has_binder"
    "test=$test"
    "repository=$repository"
)

# Ensure Python and Node.js are installed and switch to the correct versions
if [ ! -d "$HOME/.pyenv/versions/$PYTHON_VERSION" ]; then
    pyenv install $PYTHON_VERSION
fi
pyenv local $PYTHON_VERSION || echo "pyenv not found"

python -m venv .venv
source .venv/bin/activate

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install $NODE_VERSION
nvm use $NODE_VERSION

pip install cookiecutter jupyterlab==4 jupyterlite-core

# Create directory if it doesn't exist
if [ ! -d "extensions/dist" ]; then
    mkdir -p extensions/dist
fi
cd extensions/dist

# Use cookiecutter with the template path if it exists, otherwise use the URL
if [ ! -d "$COOKIECUTTER_TEMPLATE_PATH" ]; then
    cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
    echo "Created extension using cookiecutter template."
else
    # COOKIECUTTER_OPTIONS[0]="$COOKIECUTTER_TEMPLATE_PATH"  
    cookiecutter "${COOKIECUTTER_OPTIONS[@]}"
    echo "Created extension using cached cookiecutter template."
fi

# Copy the index.ts file if both source and destination directories exist
SRC_FILE="../src/$EXTENSION_NAME/index.ts"
DEST_DIR="./$EXTENSION_NAME/src"
if [ -f "$SRC_FILE" ] && [ -d "$DEST_DIR" ]; then
    cp "$SRC_FILE" "$DEST_DIR/index.ts"
else
    echo "Source file or destination directory not found. Skipping copy."
fi

cd $EXTENSION_NAME
pip install -ve .
jupyter labextension develop --overwrite .

# Install dependencies
jlpm add @jupyterlab/application
jlpm add @jupyterlab/notebook
jlpm add @exabyte-io/code.js

# Build the extension
jlpm run build

cd ../../../

# add to requirements.txt
LINE="./extensions/dist/$EXTENSION_NAME"
FILE='requirements.txt'
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# Install extension
[[ ! -z $INSTALL ]] && python -m pip install -r requirements.txt

# Build JupyterLite
[[ ! -z $BUILD ]] && jupyter lite build --contents content --output-dir dist

# Exit with zero (for GH workflow)
exit 0
