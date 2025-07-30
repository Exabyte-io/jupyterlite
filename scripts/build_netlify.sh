#!/bin/bash
set -e
nvm install 20
nvm use 20
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
npm run build
