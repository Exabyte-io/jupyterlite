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
  
    /* Incoming messages management */
    window.addEventListener('message', event => {
      if (event.data.type === 'from-host-to-iframe') {
        console.log('Message received in the iframe:', event.data);
      }
    });

    /* Outgoing messages management */
    // @ts-ignore
    const sendMaterialsData = (): void => {
      const message = {
        type: 'from-iframe-to-host',
        materials: "supposed to be materials data"
      };
      window.parent.postMessage(message, '*');
      console.log('Message sent to the host:', message);
    }
  }
};

export default plugin;
