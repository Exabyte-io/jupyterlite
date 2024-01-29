PYTHON_VERSION="3.8.6"
NODE_VERSION="14.19"
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

# Ensure Python and Node.js are installed and switch to the correct versions
if [ ! -d "$HOME/.pyenv/versions/$PYTHON_VERSION" ]; then
    pyenv install $PYTHON_VERSION
fi
pyenv local $PYTHON_VERSION

python -m venv .venv
source .venv/bin/activate

nvm install $NODE_VERSION
nvm use $NODE_VERSION

pip install cookiecutter

# Create directory if it doesn't exist
if [ ! -d "extensions/dist" ]; then
    mkdir -p extensions/dist
fi
cd extensions/dist

if [ ! -d "$COOKIECUTTER_TEMPLATE_PATH" ]; then

    cookiecutter $GITHUB_TEMPLATE_URL\
        kind="$kind" \
        author_name="$author_name" \
        author_email="$author_email" \
        labextension_name="$labextension_name" \
        python_name="$python_name" \
        project_short_description="$project_short_description" \
        has_settings="$has_settings" \
        has_binder="$has_binder" \
        test="$test" \
        repository="$repository"
    echo "Created extension using cookiecutter template."
else
    cookiecutter $COOKIECUTTER_TEMPLATE_PATH \
        kind="$kind" \
        author_name="$author_name" \
        author_email="$author_email" \
        labextension_name="$labextension_name" \
        python_name="$python_name" \
        project_short_description="$project_short_description" \
        has_settings="$has_settings" \
        has_binder="$has_binder" \
        test="$test" \
        repository="$repository"
    echo "Created extension using cached cookiecutter template."
fi

# Ensure the source and destination directories for copying exist
if [ -f "../src/$EXTENSION_NAME/index.ts" ] && [ -d "./$EXTENSION_NAME/src" ]; then
    cp "../src/$EXTENSION_NAME/index.ts" "./$EXTENSION_NAME/src/index.ts"
else
    echo "Source file or destination directory not found. Skipping copy."
fi
