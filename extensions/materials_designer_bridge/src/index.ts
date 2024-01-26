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

    console.log(app.shell);

    // @ts-ignore
    window.sendDataToHost = (materials: any) => {
      window.parent.postMessage(
        {
          type: 'from-iframe-to-host',
          materials: materials
        },
        '*'
      );
    };

    // @ts-ignore
    window.requestMaterialsFromHost = () => {
      window.parent.postMessage(
        {
          type: 'from-iframe-to-host',
          requestMaterials: true
        },
        '*'
      );
    };

    //TODO: set type for materials
    window.addEventListener('message', async event => {
      if (event.data.type === 'from-host-to-iframe') {
        let materials = event.data.materials;
        const materialsJson = JSON.stringify(materials);
        const code = `
import json
materials = json.loads('${materialsJson}')
`;

        const currentWidget = app.shell.currentWidget;

        if (currentWidget instanceof NotebookPanel) {
          const notebookPanel = currentWidget;
          const kernel = notebookPanel.sessionContext.session?.kernel;
          if (kernel) {
            kernel.requestExecute({ code: code });
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
