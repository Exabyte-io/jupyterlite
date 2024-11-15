#!/bin/bash

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
