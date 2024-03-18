#!/bin/bash

rm -rf dist/extensions/data_bridge
cd extensions/dist/data_bridge
jlpm run build

cd ../../..

npm run build && npm run start -p=8000
