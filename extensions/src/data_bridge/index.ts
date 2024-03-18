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
                    // @ts-ignore
                    if (_.status === 'idle' && !_.isInitated) {
                        console.log("Kernel is idle");
                        // @ts-ignore
                        console.log("dataFromHost", app.dataFromHost);
                        // @ts-ignore
                        _.isInitated = true;
                        const kernel = sessionContext.session?.kernel;
                        console.log("kernel", kernel);
                        loadData(kernel);
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
                loadData(kernel);
            }

        });

        const loadData = (kernel: any) => {
            const dataFromHostString = JSON.stringify(app.dataFromHost);
            // @ts-ignore
            const result = kernel.requestExecute({code: `import json\ndata = json.loads(${dataFromHostString})`});
// @ts-ignore
            console.log("Execution result", result, app.dataFromHost);
        }
    },
};


export default plugin;
