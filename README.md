# JupyterLite Demo

[![lite-badge](https://jupyterlite.rtfd.io/en/latest/_static/badge.svg)](https://jupyterlite.github.io/demo)

JupyterLite deployed as a static site to GitHub Pages, for demo purposes.

## ✨ Try it in your browser ✨

➡️ **https://jupyterlite.github.io/demo**

![github-pages](https://user-images.githubusercontent.com/591645/120649478-18258400-c47d-11eb-80e5-185e52ff2702.gif)

## Requirements

JupyterLite is being tested against modern web browsers:

- Firefox 90+
- Chromium 89+

## Deploy your JupyterLite website on GitHub Pages

Check out the guide on the JupyterLite documentation: https://jupyterlite.readthedocs.io/en/latest/quickstart/deploy.html

## Development of Extensions
### To develop extension:

```
cd jupyter-lite
mkdir extensions
```

Create virtual environment for development and install cookiecutter
```
virtualenv .venv
source .venv/bin/activate  
pip install cookiecutter
cookiecutter https://github.com/jupyterlab/extension-cookiecutter-ts
```

Create extension
```
cd extensions
mkdir jupyterlab-iframe-bridge-example
cd jupyterlab-iframe-bridge-example
jupyter labextension develop --overwrite .
```

Build the Jupyter Lab extension
```
jlpm run build
```

List available extensions
```
jupyter labextension list
```

If successful, you should see the following output:
```
jupyterlab-iframe-bridge-example v0.1.0 enabled OK (python, jupyterlab_iframe_bridge_example)
```

###  To run extension:
Specify path to custom extension pyproject.toml in requirements.txt and install dependencies

```
pip install -r requirements.txt
```

Build jupyterlite
```
jupyter lite build --contents content --output-dir dist
```

Serve jupyterlite on localhost
```
python -m http.server -b localhost -d ./dist
```

## Further Information and Updates

For more info, keep an eye on the JupyterLite documentation:

- How-to Guides: https://jupyterlite.readthedocs.io/en/latest/howto/index.html
- Reference: https://jupyterlite.readthedocs.io/en/latest/reference/index.html
