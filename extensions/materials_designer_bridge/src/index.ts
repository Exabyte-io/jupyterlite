import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

declare global {
  interface Window {
    pyodide: any;
  }
}

const PYODIDE_CDN_URL =
  'https://cdn.jsdelivr.net/pyodide/v0.24.1/full/pyodide.js';

/**
 * Initialization data for the materials-designer-bridge extension.
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: 'materials-designer-bridge:plugin',
  description:
    'Extension to pass materials data between Materials Designer and Jupyter Lite instance',
  autoStart: true,
  activate: (app: JupyterFrontEnd) => {
    console.log(
      'MD Extension. JupyterLab extension materials-designer-bridge is activated!'
    );

    // Load Pyodide
    if (!window.pyodide) {
      const script = document.createElement('script');
      script.src = PYODIDE_CDN_URL;
      script.async = true;
      script.onload = async () => {
        // Initialize Pyodide after the script is loaded
        // @ts-ignore
        window.pyodide = await window.loadPyodide();

        console.log('MD Extension. Pyodide initialized successfully.');
      };
      script.onerror = () => {
        console.error('MD Extension. There was an error loading Pyodide.');
      };
      document.head.appendChild(script);
    }

    /* Incoming messages management */
    window.addEventListener('message', event => {
      console.log('MD Extension. Event received from the host:', event);
      if (event.data.type === 'from-host-to-iframe') {
        let materials = event.data.materials;
        console.log(
          'MD Extension. Materials received in the iframe:',
          materials
        );
        // @ts-ignore
        window.materials = materials;
        localStorage.setItem('materials', JSON.stringify(materials));

        // Send materials to Pyodide Python environment
        if (
          window.pyodide &&
          typeof window.pyodide.runPythonAsync === 'function'
        ) {
          window.pyodide
            .runPythonAsync(
              `
              import json
              materials = json.loads('${JSON.stringify(materials)}')
              print('MD Extension. Materials received in the Python environment:', materials)
              # function defined in the Python notebook
              get_materials(materials)
            `
            )
            .then(() => {
              console.log('MD Extension. Python code executed successfully.');
            })
            .catch((err: any) => {
              console.error(
                'MD Extension. There was an error executing Python code:',
                err
              );
            });
        } else {
          console.error('MD Extension. Pyodide is not available.');
        }
      }
    });

    /* Outgoing messages management */
    // @ts-ignore
    const sendMaterialsData = (): void => {
      const message = {
        type: 'from-iframe-to-host',
        materials: 'MD Extension. supposed to be materials data'
      };
      window.parent.postMessage(message, '*');
      console.log('MD Extension. Message sent to the host:', message);
    };

    // Example usage of sendMaterialsData function
    // sendMaterialsData();
  }
};

export default plugin;
