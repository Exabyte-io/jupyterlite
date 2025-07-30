#!/bin/bash
set -e
echo "Node.js version: $(node --version)"
echo "Python version: $(python --version)"
echo "npm version: $(npm --version)"
npm run build
