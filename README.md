# Mat3ra-Jupyterlite

Available at [https://mat3ra-jupyterlite.netlify.app/lab/index.html](https://mat3ra-jupyterlite.netlify.app/lab/index.html).

# JupyterLite Environment

[![lite-badge](https://jupyterlite.rtfd.io/en/latest/_static/badge.svg)](https://jupyterlite.github.io/demo)

JupyterLite deployed as a static site to GitHub Pages, for demo purposes.

## ✨ Try it in your browser ✨

➡️ **https://jupyterlite.mat3ra.com**

![github-pages](https://user-images.githubusercontent.com/591645/120649478-18258400-c47d-11eb-80e5-185e52ff2702.gif)

## Development Notes

### Extensions

The environment using the [data-bridge extension](https://github.com/Exabyte-io/mat3ra-jupyterlite-extension-data-bridge) (see [requirements.txt](dependencies/requirements.txt)).

### Content

The content is based on the [api-examples](https://github.com/Exabyte-io/api-examples.git). And is being populated during build.

### Build

As below:

To build and run the environment locally:

1. check that `npm` is installed
2. run:
```bash
npm install
npm run build
npm start
```

See [github workflow](.github/workflows/deploy.yml) and [package.json](package.json) for more information.

### Build Approach (Current)

Build logic is split by responsibility:

- `scripts/install.sh`: local/CI dev environment setup (Python, Node, venv, python deps)
- `scripts/build.sh`: content sync, pyodide download, wheel collection, and `jupyter lite build`
- `scripts/download_pyodide.sh`: download fixed Pyodide version (`0.24.1`) into `dist/pyodide`
- `scripts/download_packages.sh`: populate `content/packages` from `content/config.yml`

### Package Loading Strategy

`content/config.yml` can include:

- `emfs:/drive/packages/<wheel>.whl` for explicit local wheel installs from `dist/files/packages`
- named packages (for example `scipy==1.11.2`, `plotly>=5.18`) resolved by micropip/piplite flow

Pyodide startup packages (for example `numpy`, `scipy`, `pandas`) are patched into `dist/jupyter-lite.json` during build.

### Build Commands

```bash
npm run setup                 # install.sh only
npm run build                 # refresh content + download packages + build
npm run build:refresh-content # refresh content + download packages + build
npm run build:fast            # build only (no content refresh, no package download)
npm run start                 # serve dist on localhost:8000
```
