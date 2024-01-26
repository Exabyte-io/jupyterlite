from IPython.display import display, Javascript
import json


def submit(data):
    python_data = data
    serialized_data = json.dumps(python_data)
    js_code = f"""
    (function() {{
        window.sendDataToHost({serialized_data})
    }})();
    """

    display(Javascript(js_code))
    print("Status: materials sent")


def get_materials():
    js_code = """
    (function() {
        if (window.requestMaterialsFromHost) {
            window.requestMaterialsFromHost();
        } else {
            console.error('requestMaterialsFromHost function is not defined on the window object.');
        }
    })();
    """

    display(Javascript(js_code))
    print("Status: materials updated")
