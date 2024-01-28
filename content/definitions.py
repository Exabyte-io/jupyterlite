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


from pymatgen.core import Structure, Lattice


def to_pymatgen(material_data):
    lattice_params = material_data["lattice"]
    lattice_vectors = lattice_params["vectors"]
    a = lattice_vectors["a"]
    b = lattice_vectors["b"]
    c = lattice_vectors["c"]

    # Create a Lattice
    lattice = Lattice([a, b, c])

    # Extract the basis information
    basis = material_data["basis"]
    elements = [element["value"] for element in basis["elements"]]
    coordinates = [coord["value"] for coord in basis["coordinates"]]

    # Assuming that the basis units are fractional since it's a crystal basis
    coords_are_cartesian = basis["units"].lower() != "crystal"

    # Create the Structure
    structure = Structure(
        lattice, elements, coordinates, coords_are_cartesian=coords_are_cartesian
    )

    return structure
