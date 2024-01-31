import {
    JupyterFrontEnd,
    JupyterFrontEndPlugin,
} from "@jupyterlab/application";

import { NotebookPanel, INotebookTracker } from "@jupyterlab/notebook";

/**
 * Initialization data for the data-bridge extension.
 * Similar to https://jupyterlite.readthedocs.io/en/latest/howto/configure/advanced/iframe.html
 */
const plugin: JupyterFrontEndPlugin<void> = {
    id: "data-bridge:plugin",
    description:
        "Extension to pass JSON data between host page and Jupyter Lite instance",
    autoStart: true,
    requires: [INotebookTracker],
    activate: async (
        app: JupyterFrontEnd,
        notebookTracker: INotebookTracker
    ) => {
        console.log("JupyterLab extension data-bridge is activated!");

        // Send path of the currently opened notebook to the host page when the notebook is opened
        notebookTracker.currentChanged.connect((sender, notebookPanel) => {
            if (notebookPanel) {
                const currentPath = notebookPanel.context.path;

                window.parent.postMessage(
                    {
                        type: "from-iframe-to-host",
                        path: currentPath,
                    },
                    "*"
                );
            }
        });

        // @ts-ignore
        window.sendDataToHost = (data: any) => {
            window.parent.postMessage(
                {
                    type: "from-iframe-to-host",
                    data: data,
                },
                "*"
            );
        };

        // @ts-ignore
        window.requestDataFromHost = () => {
            window.parent.postMessage(
                {
                    type: "from-iframe-to-host",
                    requestData: true,
                },
                "*"
            );
        };

        window.addEventListener("message", async (event) => {
            if (event.data.type === "from-host-to-iframe") {
                let data = event.data.data;
                const dataJson = JSON.stringify(data);
                const code = `
    import json
    data = json.loads('${dataJson}')
    `;
                // Similar to https://jupyterlab.readthedocs.io/en/stable/api/classes/application.LabShell.html#currentWidget
                // https://jupyterlite.readthedocs.io/en/latest/reference/api/ts/interfaces/jupyterlite_application.ISingleWidgetShell.html#currentwidget
                const currentWidget = app.shell.currentWidget;

                if (currentWidget instanceof NotebookPanel) {
                    const notebookPanel = currentWidget;
                    const kernel = notebookPanel.sessionContext.session?.kernel;
                    if (kernel) {
                        kernel.requestExecute({ code: code });
                    } else {
                        console.error("No active kernel found");
                    }
                } else {
                    console.error("Current active widget is not a notebook");
                }
            }
        });
    },
};

export default plugin;
