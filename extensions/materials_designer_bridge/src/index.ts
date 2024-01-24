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
    console.log('MD Extension. JupyterLab extension materials-designer-bridge is activated!');

    // Define a command that sends data to the kernel
    const commandId = 'my-extension:send-data-to-kernel';

    app.commands.addCommand(commandId, {
      execute: () => {
        // Get the current kernel 
        const kernel = app.serviceManager.sessions.findByPath('debugging_jl.ipynb');
        console.log('MD Extension. Kernel:', kernel);
        // Send a message to the kernel
        kernel.then(session => {
          // @ts-ignore
          session.kernel.requestExecute({ code: `get_materials(${JSON.stringify(window.materials)})` });
        });
      }
    });

    /* Incoming messages management */
    window.addEventListener('message', event => {
      console.log('MD Extension. Event received from the host:', event);
      if (event.data.type === 'from-host-to-iframe') {
        console.log('MD Extension. Message received in the iframe:', event.data);
        let materials = event.data.materials;
        console.log('MD Extension. Materials received in the iframe:', materials);
        // @ts-ignore
        window.materials = materials;
        // @ts-ignore
        console.log('MD Extension. Materials stored in the iframe:', window.materials);


        // TODO: reserve in case previous approach doesn't work
        // const kernel = app.serviceManager.sessions.findByPath('path-to-your-notebook');
        // kernel.then(session => {
        //   let materials = event.data.materials;
        //   session.kernel.requestExecute({ code: `your_python_function(${JSON.stringify(materials)})` });
        // });


        // Execute the command to send data to the kernel
        app.commands.execute(commandId);
      }
    });

    /* Outgoing messages management */
    // @ts-ignore
    const sendMaterialsData = (): void => {
      const message = {
        type: 'from-iframe-to-host',
        materials: "MD Extension. supposed to be materials data"
      };
      window.parent.postMessage(message, '*');
      console.log('MD Extension. Message sent to the host:', message);
    }
  }
};

export default plugin;
