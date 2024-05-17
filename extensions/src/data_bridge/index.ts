/* eslint-disable @typescript-eslint/ban-ts-comment */
// @ts-nocheck
import {
    JupyterFrontEnd,
    JupyterFrontEndPlugin
} from "@jupyterlab/application";

import { IKernelConnection } from "@jupyterlab/services/lib/kernel/kernel";
import { NotebookPanel, INotebookTracker } from "@jupyterlab/notebook";
import { IframeMessageSchema } from "@mat3ra/esse/lib/js/types";

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
    activate: async (app: JupyterFrontEnd, notebookTracker: INotebookTracker) => {
        console.log("JupyterLab extension data-bridge is activated!");

        // Variable to hold the data from the host page
        let dataFromHost = "";
        // When data is loaded into the kernel, save it into this object to later check it to avoid reloading the same data
        const kernelsDataFromHost: { [id: string]: string } = {};

        const MESSAGE_GET_DATA_CONTENT = {
            type: "from-iframe-to-host",
            action: "get-data",
            payload: {}
        };

        // On JupyterLite startup send get-data message to the host to request data
        window.parent.postMessage(MESSAGE_GET_DATA_CONTENT, "*");

        /**
         * Listen for the current notebook being changed, and on kernel status change load the data into the kernel
         */
        notebookTracker.currentChanged.connect(
            // @ts-ignore
            async (sender, notebookPanel: NotebookPanel) => {
                if (notebookPanel) {
                    console.debug("Notebook opened", notebookPanel.context.path);
                    await notebookPanel.sessionContext.ready;
                    const sessionContext = notebookPanel.sessionContext;

                    sessionContext.session?.kernel?.statusChanged.connect(
                        (kernel, status) => {
                            if (
                                status === "idle" &&
                                kernelsDataFromHost[kernel.id] !== dataFromHost
                            ) {
                                loadData(kernel, dataFromHost);
                                // Save data for the current kernel to avoid reloading the same data
                                kernelsDataFromHost[kernel.id] = dataFromHost;
                            }
                            // Reset the data when the kernel is restarting, since the loaded data is lost
                            if (status === "restarting") {
                                kernelsDataFromHost[kernel.id] = "";
                            }
                        }
                    );
                }
            }
        );

        /**
         * Send data to the host page
         * @param data
         */
        // @ts-ignore
        window.sendDataToHost = (data: object) => {
            const MESSAGE_SET_DATA_CONTENT = {
                type: "from-iframe-to-host",
                action: "set-data",
                payload: data
            };
            window.parent.postMessage(MESSAGE_SET_DATA_CONTENT, "*");
        };

        /**
         * Listen for messages from the host page, and update the data in the kernel
         * @param event MessageEvent
         */
        window.addEventListener(
            "message",
            async (event: MessageEvent<IframeMessageSchema>) => {
                if (event.data.type === "from-host-to-iframe") {
                    dataFromHost = JSON.stringify(event.data.payload);
                    const notebookPanel = notebookTracker.currentWidget;
                    await notebookPanel?.sessionContext.ready;
                    const sessionContext = notebookPanel?.sessionContext;
                    const kernel = sessionContext?.session?.kernel;
                    if (kernel) {
                        loadData(kernel, dataFromHost);
                    }
                }
            }
        );

        /**
         * Load the data into the kernel by executing code
         * @param kernel
         * @param data string representation of JSON
         */
        const loadData = (kernel: IKernelConnection, data: string) => {
            const code = `import json\ndata_from_host = json.loads(r'''${data}''')`;
            const result = kernel.requestExecute({ code: code });
            console.debug("Execution result:", result);
        };
    }
};

export default plugin;
