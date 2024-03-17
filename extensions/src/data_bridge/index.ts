// @ts-nocheck
import {
    JupyterFrontEnd,
    JupyterFrontEndPlugin,
} from "@jupyterlab/application";

import {NotebookPanel, INotebookTracker, NotebookAdapter} from "@jupyterlab/notebook";
import {IframeMessageSchema} from "@mat3ra/esse/lib/js/types";

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
        notebookTracker: INotebookTracker,
        notebookAdapter: NotebookAdapter
    ) => {
        console.log("JupyterLab extension data-bridge is activated!");

        // variable to hold the data from the host page
        // @ts-ignore
        app.dataFromHost = "";

        // @ts-ignore
        notebookTracker.currentChanged.connect(async (sender, notebookPanel: NotebookPanel) => {
            if (notebookPanel) {
                console.log("Notebook opened", notebookPanel.context.path);
                await notebookPanel.sessionContext.ready;
                const sessionContext = notebookPanel.sessionContext;

                sessionContext.kernelChanged.connect((_, kernel) => {
                    console.log("Kernel changed", kernel);
                    console.log("sessionContext.kernel", sessionContext);
                });

                sessionContext.session?.kernel?.statusChanged.connect((_, status) => {
                    console.log("Kernel status changed", status);
                    console.log("_", _);
                });

                if (notebookPanel.sessionContext.session?.kernel?.status === 'idle') {
                    console.log("Kernel is idle");
                    const kernel = notebookPanel.sessionContext.session.kernel;
                    // @ts-ignore
                    console.log("dataFromHost", app.dataFromHost);
                    // @ts-ignore
                    kernel.requestExecute({ code: `data = ${app.dataFromHost}` });
                }
            }
        });


        // Similar to https://jupyterlab.readthedocs.io/en/stable/api/classes/application.LabShell.html#currentWidget
        // https://jupyterlite.readthedocs.io/en/latest/reference/api/ts/interfaces/jupyterlite_application.ISingleWidgetShell.html#currentwidget
        const currentWidget = app.shell.currentWidget;
        if (currentWidget instanceof NotebookPanel) {
            const notebookPanel = currentWidget;
            const sessionContext = notebookPanel.sessionContext;
            sessionContext.kernelChanged.connect((_, kernel) => {
                console.log("Kernel changed", kernel);
            });
            const kernel = notebookPanel.sessionContext.session?.kernel;
            if (kernel) {
                // @ts-ignore
                kernel.requestExecute(`data = ${app.dataFromHost}`);
            } else {
                console.error("No active kernel found");
            }
        } else {
            console.error("Current active widget is not a notebook");
        }

        // @ts-ignore
        window.sendDataToHost = (data: any) => {
            window.parent.postMessage(
                {
                    type: "from-iframe-to-host",
                    action: "set-data",
                    payload: {
                        data: data,
                    },
                },
                "*"
            );
        };


        // @ts-ignore
        window.addEventListener("message", async (event: MessageEvent<IframeMessageSchema>) => {
            if (event.data.type === "from-host-to-iframe") {
                let data = event.data.payload.data;
                const dataJson = JSON.stringify(data);
                // @ts-ignore
                app.dataFromHost = dataJson;
                //@ts-ignore
                console.log("Data from host received. app:", app.dataFromHost);
            }

        });
    },
};


export default plugin;