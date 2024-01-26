import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

import { NotebookPanel } from '@jupyterlab/notebook';

/**
 * Initialization data for the materials-designer-bridge extension.
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: 'materials-designer-bridge:plugin',
  description:
    'Extension to pass materials data between Materials Designer and Jupyter Lite instance',
  autoStart: true,
  activate: async (app: JupyterFrontEnd) => {
    console.log(
      'MD Extension. JupyterLab extension materials-designer-bridge is activated!'
    );

    window.addEventListener('message', async event => {
      console.log('MD Extension. Event received from the host:', event);
      if (event.data.type === 'from-host-to-iframe') {
        let materials = event.data.materials;
        console.log(
          'MD Extension. Materials received in the iframe:',
          materials
        );
        // @ts-ignore
        window.materials = materials;
        console.log(
          'MD Extension. Materials stored in the window object.',
          // @ts-ignore
          window.materials
        );

        const code = `
import json
materials = json.loads('${JSON.stringify(materials[0])
          .replace(/'/g, "\\'")
          .replace(/"/g, '\\"')}')
print('Materials stored in the kernel globals')
`;

        // Assigns materials to globals in the pyodide kernel
        const currentWidget = app.shell.currentWidget;
        console.log('MD Extension. Current widget:', currentWidget);
        // Check if the current widget is a notebook
        if (currentWidget instanceof NotebookPanel) {
          const notebookPanel = currentWidget as NotebookPanel;
          const kernel = notebookPanel.sessionContext.session?.kernel;
          console.log('MD Extension. Current kernel:', kernel);
          if (kernel) {
            // Execute the code in the kernel
            kernel.requestExecute({ code: code });
            console.log('MD Extension. Executed code in the kernel:', code);
          } else {
            console.error('No active kernel found');
          }
        } else {
          console.error('Current active widget is not a notebook');
        }
      }
    });
  }
};

export default plugin;
