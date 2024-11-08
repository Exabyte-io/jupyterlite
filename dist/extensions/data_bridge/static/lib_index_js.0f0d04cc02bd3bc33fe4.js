"use strict";
(self["webpackChunkdata_bridge"] = self["webpackChunkdata_bridge"] || []).push([["lib_index_js"],{

/***/ "./lib/index.js":
/*!**********************!*\
  !*** ./lib/index.js ***!
  \**********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__)
/* harmony export */ });
/* harmony import */ var _jupyterlab_notebook__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @jupyterlab/notebook */ "webpack/sharing/consume/default/@jupyterlab/notebook");
/* harmony import */ var _jupyterlab_notebook__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_jupyterlab_notebook__WEBPACK_IMPORTED_MODULE_0__);

/**
 * Initialization data for the data-bridge extension.
 * Similar to https://jupyterlite.readthedocs.io/en/latest/howto/configure/advanced/iframe.html
 */
const plugin = {
    id: "data-bridge:plugin",
    description: "Extension to pass JSON data between host page and Jupyter Lite instance",
    autoStart: true,
    requires: [_jupyterlab_notebook__WEBPACK_IMPORTED_MODULE_0__.INotebookTracker],
    activate: async (app, notebookTracker) => {
        console.log("JupyterLab extension data-bridge is activated!");
        // Variable to hold the data from the host page
        let dataFromHost = "";
        // When data is loaded into the kernel, save it into this object to later check it to avoid reloading the same data
        const kernelsDataFromHost = {};
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
        async (sender, notebookPanel) => {
            var _a, _b;
            if (notebookPanel) {
                console.debug("Notebook opened", notebookPanel.context.path);
                await notebookPanel.sessionContext.ready;
                const sessionContext = notebookPanel.sessionContext;
                (_b = (_a = sessionContext.session) === null || _a === void 0 ? void 0 : _a.kernel) === null || _b === void 0 ? void 0 : _b.statusChanged.connect((kernel, status) => {
                    if (status === "idle" &&
                        kernelsDataFromHost[kernel.id] !== dataFromHost) {
                        loadData(kernel, dataFromHost);
                        // Save data for the current kernel to avoid reloading the same data
                        kernelsDataFromHost[kernel.id] = dataFromHost;
                    }
                    // Reset the data when the kernel is restarting, since the loaded data is lost
                    if (status === "restarting") {
                        kernelsDataFromHost[kernel.id] = "";
                    }
                });
            }
        });
        /**
         * Send data to the host page
         * @param data
         */
        // @ts-ignore
        window.sendDataToHost = (data) => {
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
        window.addEventListener("message", async (event) => {
            var _a;
            if (event.data.type === "from-host-to-iframe") {
                dataFromHost = JSON.stringify(event.data.payload);
                const notebookPanel = notebookTracker.currentWidget;
                await (notebookPanel === null || notebookPanel === void 0 ? void 0 : notebookPanel.sessionContext.ready);
                const sessionContext = notebookPanel === null || notebookPanel === void 0 ? void 0 : notebookPanel.sessionContext;
                const kernel = (_a = sessionContext === null || sessionContext === void 0 ? void 0 : sessionContext.session) === null || _a === void 0 ? void 0 : _a.kernel;
                if (kernel) {
                    loadData(kernel, dataFromHost);
                }
            }
        });
        /**
         * Load the data into the kernel by executing code
         * @param kernel
         * @param data string representation of JSON
         */
        const loadData = (kernel, data) => {
            const code = `import json\ndata_from_host = json.loads(r'''${data}''')`;
            const result = kernel.requestExecute({ code: code });
            console.debug("Execution result:", result);
        };
    }
};
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (plugin);


/***/ })

}]);
//# sourceMappingURL=lib_index_js.0f0d04cc02bd3bc33fe4.js.map