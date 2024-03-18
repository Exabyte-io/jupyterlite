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

                sessionContext.session?.kernel?.statusChanged.connect((kernel, status) => {
                    // @ts-ignore
                    console.log( status, kernel.id);
                    // @ts-ignore
                    if (kernel.status === 'idle' && kernel.dataFromHost !== app.dataFromHost) {
                        // @ts-ignore
                        kernel.dataFromHost = app.dataFromHost;
                        loadData(kernel, app.dataFromHost);
                    }
                });
            }
        });

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
                // Execute code in the kernel
                const notebookPanel = notebookTracker.currentWidget;
                await notebookPanel.sessionContext.ready;
                const sessionContext = notebookPanel.sessionContext;
                const kernel = sessionContext.session?.kernel;
                loadData(kernel, data);
            }

        });

        const loadData = (kernel: any, data: any) => {
            const dataFromHostString = JSON.stringify(data);

            const code = `import json\ndata = json.loads(${dataFromHostString})`;
            // @ts-ignore
            const result = kernel.requestExecute({code: code});
            // @ts-ignore
            console.log("Execution result", result, app.dataFromHost);
        }
    },
};


export default plugin;
