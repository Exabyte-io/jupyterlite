import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';
import { KernelManager, KernelSpecManager } from '@jupyterlab/services';

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

    const kernelManager = new KernelManager();
    const kernelSpecManager = new KernelSpecManager();
    await kernelSpecManager.ready;

    // Start a new kernel session
    const specs = kernelSpecManager.specs;
    // @ts-ignore
    const defaultSpecName = specs.default;
    const session = await kernelManager.startNew({
      name: defaultSpecName
    });
    console.log('MD Extension. Kernel session started.');

    window.addEventListener('message', async event => {
      console.log('MD Extension. Event received from the host:', event);
      if (event.data.type === 'from-host-to-iframe') {
        let materials = event.data.materials;
        console.log(
          'MD Extension. Materials received in the iframe:',
          materials
        );

        // @ts-ignore
        const future = session.kernel.requestExecute({
          code: `
            import json
            global materials
            materials = json.loads('${JSON.stringify(materials)}')
            print(materials)
          `
        });

        future.done
          .then(() => {
            console.log('MD Extension. Code executed in Python kernel.');
          })
          // @ts-ignore
          .catch(err => {
            console.error(
              'MD Extension. Error executing code in Python kernel:',
              err
            );
          });

        // Clean up after execution
        future.done.finally(() => {
          session.dispose();
        });
      }
    });
  }
};

export default plugin;
