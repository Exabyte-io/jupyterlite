#!/bin/bash
# This script rebuilds the JupyterLab extension and starts the JupyterLite server
# Meant to automate the process during development

rm -rf dist/extensions/data_bridge
cd extensions/dist/data_bridge
jlpm run build

cd ../../..

npm run build && npm run start -p=8000
