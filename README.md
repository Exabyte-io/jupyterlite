# JupyterLite Demo

[![lite-badge](https://jupyterlite.rtfd.io/en/latest/_static/badge.svg)](https://jupyterlite.github.io/demo)

JupyterLite deployed as a static site to GitHub Pages, for demo purposes.

## ✨ Try it in your browser ✨

➡️ **https://jupyterlite.github.io/demo**

![github-pages](https://user-images.githubusercontent.com/591645/120649478-18258400-c47d-11eb-80e5-185e52ff2702.gif)

## Requirements

JupyterLite is being tested against modern web browsers:

-   Firefox 90+
-   Chromium 89+

## Deploy your JupyterLite website on GitHub Pages

Check out the guide on the JupyterLite documentation: https://jupyterlite.readthedocs.io/en/latest/quickstart/deploy.html

## Further Information and Updates

For more info, keep an eye on the JupyterLite documentation:

-   How-to Guides: https://jupyterlite.readthedocs.io/en/latest/howto/index.html
-   Reference: https://jupyterlite.readthedocs.io/en/latest/reference/index.html

## Development Notes

To build and run the JupyterLite server with extension, we use the following steps:
-   check that `pyenv` and `npm` are installed
-   run `npm install` to install the required packages and setup the `data_bridge` extension
-   run `npm install INSTALL=1 BUILD=1` to also build and install the jupyter lite with extension
-   `requirements.txt` is updated as part of the above to include the extension
-   run `npm run start -p=8000` to start the server (specify the port if needed)
-   content is populated with a submodule of `exabyte-io/api-examples`

To develop the extension:
-   run `npm install` or `sh setup.sh` to create the extension
-   change code in `extensions/dist/data_bridge/src/index.ts`
-   run `npm run restart` or `sh update.sh` to build the extension, install it, and restart the server with it

To publish:
-   commit changes to the `extensions/src/data_bridge/index.ts` file

```shell
cd content
git submodule add https://github.com/exabyte-io/api-examples.git api-examples
```

-   The `api-examples` repository utilizes symbolic links (symlinks) for certain folder structures. During the build process, we create an intermediary `content-resolved` folder using the `cp -rL` command. This command copies the `content` directory and resolves all symlinks to their referenced files or directories. This step ensures that the symlinks function correctly within JupyterLite.

Here's the command we use for the build process:

```shell
cp -rL content content-resolved; jupyter lite build --contents content-resolved --output-dir dist
```
