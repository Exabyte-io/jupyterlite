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

        // Variable to hold the data from the host page, accessible from any notebook and kernel
        // @ts-ignore
        app.dataFromHost = "";

        // On JupyterLite startup send get-data message to the host to request data
        window.parent.postMessage(
            {
                type: "from-iframe-to-host",
                action: "get-data",
                payload: {}
            },
            "*"
        );


        /**
         * Listen for the current notebook being changed, and on kernel status change load the data into the kernel
         */
        // @ts-ignore
        notebookTracker.currentChanged.connect(async (sender, notebookPanel: NotebookPanel) => {
            if (notebookPanel) {
                console.debug("Notebook opened", notebookPanel.context.path);
                await notebookPanel.sessionContext.ready;
                const sessionContext = notebookPanel.sessionContext;

                sessionContext.session?.kernel?.statusChanged.connect((kernel, status) => {
                    // @ts-ignore
                    console.debug(status, kernel.id, kernel.dataFromHost);
                    // @ts-ignore
                    if (status === 'idle' && kernel.dataFromHost !== app.dataFromHost) {
                        // Custom flag to prevent from loading the same data multiple times
                        // @ts-ignore
                        kernel.dataFromHost = app.dataFromHost;
                        loadData(kernel, app.dataFromHost);
                    }
                    // Reset the flag when the kernel is restarting, since this flag is not affected by the kernel restart
                    if (status === 'restarting') {
                        kernel.dataFromHost = "";
                    }
                });
            }
        });

        /**
         * Send data to the host page
         * @param data
         */
        // @ts-ignore
        window.sendDataToHost = (data: object) => {
            window.parent.postMessage(
                {
                    type: "from-iframe-to-host",
                    action: "set-data",
                    payload: data
                },
                "*"
            );
        };

        /**
         * Listen for messages from the host page, and update the data in the kernel
         * @param event MessageEvent
         */
        // @ts-ignore
        window.addEventListener("message", async (event: MessageEvent<IframeMessageSchema>) => {
            if (event.data.type === "from-host-to-iframe") {
                // @ts-ignore
                app.dataFromHost = JSON.stringify(event.data.payload);
                //@ts-ignore
                console.debug("Data from host received. app:", app.dataFromHost);
                // Execute code in the kernel
                const notebookPanel = notebookTracker.currentWidget;
                await notebookPanel.sessionContext.ready;
                const sessionContext = notebookPanel.sessionContext;
                const kernel = sessionContext.session?.kernel;
                // @ts-ignore
                loadData(kernel, app.dataFromHost);
            }
        });

        /**
         * Load the data into the kernel by executing code
         * @param kernel
         * @param data
         */
        const loadData = (kernel: IKernelConnection, data: JSON) => {
            const dataFromHostString = JSON.stringify(data);
            const code = `import json\ndata_from_host = json.loads(${dataFromHostString})`;
            // @ts-ignore
            const result = kernel.requestExecute({code: code});
            // @ts-ignore
            console.debug("Execution result", result);
        }

    },
};


export default plugin;
