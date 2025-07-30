#!/bin/bash
set -e
nvm install 18
nvm use 18
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
npm run build
