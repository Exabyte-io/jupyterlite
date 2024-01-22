import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

/**
 * Initialization data for the materials-designer-bridge extension.
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: 'materials-designer-bridge:plugin',
  description: 'Extension to pass materials data between Materials Designer and Jupyter Lite instance',
  autoStart: true,
  activate: (app: JupyterFrontEnd) => {
    console.log('JupyterLab extension materials-designer-bridge is activated!');
  }
};

export default plugin;
