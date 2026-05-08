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

To build and run the environment locally:

1. check that `npm` is installed
2. run:
```bash
npm run install
npm run build
npm start
```

See [github workflow](.github/workflows/deploy.yml) and [package.json](package.json) for more information.

### Build Approach (Current)

Build logic is split by responsibility:

- `scripts/install.sh`: local/CI dev environment setup (Python, Node, venv, python deps)
- `scripts/build.sh`: content sync from api-examples and `jupyter lite build`
- `scripts/download_pyodide.sh`: one-time download of fixed Pyodide version into `assets/pyodide` (commit to repo)
- `scripts/download_packages.sh`: one-time population of `content/packages` from `content/config.yml` (commit to repo)

### Package Loading Strategy

`content/config.yml` can include:

- `emfs:/drive/packages/<wheel>.whl` for explicit local wheel installs from `dist/files/packages`
- named packages (for example `scipy==1.11.2`, `plotly>=5.18`) resolved by micropip/piplite flow

Pyodide startup packages (for example `numpy`, `scipy`, `pandas`) are patched into `dist/jupyter-lite.json` during build.

### Build Commands

```bash
npm run install          # Set up dev environment (venv, dependencies)
npm run setup:pyodide    # One-time: download Pyodide to assets/pyodide (commit after)
npm run setup:packages   # One-time: download wheels to content/packages (commit after)
npm run build            # Build JupyterLite (syncs content from api-examples)
npm run build:fast       # Build without syncing content
npm run start            # Serve dist on localhost:8000
```

### Initial Setup Workflow

1. `npm run install` - set up environment
2. `npm run setup:pyodide` - download Pyodide assets
3. `npm run setup:packages` - download Python wheels
4. Commit `assets/pyodide/` and `content/packages/` to repo
5. CI/local builds just use `npm run build` (no downloads needed)
