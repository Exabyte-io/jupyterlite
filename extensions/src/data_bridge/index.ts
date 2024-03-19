/* eslint-disable @typescript-eslint/ban-ts-comment */
import {
    JupyterFrontEnd,
    JupyterFrontEndPlugin
} from '@jupyterlab/application';

import { IKernelConnection } from '@jupyterlab/services/lib/kernel/kernel';
import { NotebookPanel, INotebookTracker } from '@jupyterlab/notebook';
import { IframeMessageSchema } from '@mat3ra/esse/lib/js/types';

interface IExtendedJupyterFrontEnd extends JupyterFrontEnd {
    dataFromHost: string;
}

/**
 * Initialization data for the data-bridge extension.
 * Similar to https://jupyterlite.readthedocs.io/en/latest/howto/configure/advanced/iframe.html
 */
const plugin: JupyterFrontEndPlugin<void> = {
    id: 'data-bridge:plugin',
    description:
        'Extension to pass JSON data between host page and Jupyter Lite instance',
    autoStart: true,
    requires: [INotebookTracker],
    activate: async (app: JupyterFrontEnd, notebookTracker: INotebookTracker) => {
        console.log('JupyterLab extension data-bridge is activated!');
        const extendedApp = app as IExtendedJupyterFrontEnd;
        // Reusing the `app` variable to hold the data from the host page, accessible from any notebook and kernel
        extendedApp.dataFromHost = '';

        const MESSAGE_GET_DATA_CONTENT = {
            type: 'from-iframe-to-host',
            action: 'get-data',
            payload: {}
        };

        // On JupyterLite startup send get-data message to the host to request data
        window.parent.postMessage(MESSAGE_GET_DATA_CONTENT, '*');

        /**
         * Listen for the current notebook being changed, and on kernel status change load the data into the kernel
         */
        notebookTracker.currentChanged.connect(
            // @ts-ignore
            async (sender, notebookPanel: NotebookPanel) => {
                if (notebookPanel) {
                    console.debug('Notebook opened', notebookPanel.context.path);
                    await notebookPanel.sessionContext.ready;
                    const sessionContext = notebookPanel.sessionContext;

                    sessionContext.session?.kernel?.statusChanged.connect(
                        (kernel, status) => {
                            if (
                                status === 'idle' &&
                                // @ts-ignore
                                kernel.dataFromHost !== extendedApp.dataFromHost
                            ) {
                                // Save previous data inside the current kernel to avoid reloading the same data
                                // @ts-ignore
                                kernel.dataFromHost = extendedApp.dataFromHost;
                                loadData(kernel, extendedApp.dataFromHost);
                            }
                            // Reset the flag when the kernel is restarting, since this flag is not affected by the kernel restart
                            if (status === 'restarting') {
                                // @ts-ignore
                                kernel.dataFromHost = '';
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
                type: 'from-iframe-to-host',
                action: 'set-data',
                payload: data
            };
            window.parent.postMessage(MESSAGE_SET_DATA_CONTENT, '*');
        };

        /**
         * Listen for messages from the host page, and update the data in the kernel
         * @param event MessageEvent
         */
        window.addEventListener(
            'message',
            async (event: MessageEvent<IframeMessageSchema>) => {
                if (event.data.type === 'from-host-to-iframe') {
                    extendedApp.dataFromHost = JSON.stringify(event.data.payload);
                    const notebookPanel = notebookTracker.currentWidget;
                    await notebookPanel?.sessionContext.ready;
                    const sessionContext = notebookPanel?.sessionContext;
                    const kernel = sessionContext?.session?.kernel;
                    if (kernel) {
                        loadData(kernel, extendedApp.dataFromHost);
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
            const dataFromHostString = JSON.stringify(data);
            const code = `import json\ndata_from_host = json.loads(${dataFromHostString})`;
            const result = kernel.requestExecute({ code: code });
            console.debug('Execution result', result);
        };
    }
};

export default plugin;
