"""
Pyodide startup script to preinstall common packages
Usage: 
  import startup  # This will preinstall packages
  await startup.preinstall_packages()  # Manual preinstall
"""
import sys

if sys.platform == "emscripten":
    import micropip
    
    # List of packages to preinstall - use package names since they're available via piplite
    DEFAULT_PACKAGES = [
        "pymatgen==2024.4.13",
        "spglib==2.0.2",
        "ruamel.yaml==0.17.32",
        "pydantic-core==2.18.2",
        "pydantic==2.7.1",
        "pandas==1.5.3",
        "ipywidgets",
        "plotly>=5.18",
        "nbformat>=4.2.0",
        "annotated_types>=0.6.0",
        "networkx==3.2.1",
        "monty==2023.11.3",
        "scipy==1.11.2",
        "tabulate==0.9.0",
        "sympy==1.12",
        "uncertainties==3.1.6",
        "jinja2"
    ]

    async def preinstall_packages():
        """Preinstall common packages"""
        print("🚀 Preinstalling common packages...")
        for package in DEFAULT_PACKAGES:
            try:
                await micropip.install(package, deps=True)
                pkg_name = package.split("==")[0].split(">=")[0]
                print(f"✓ {pkg_name}")
            except Exception as e:
                pkg_name = package.split("==")[0].split(">=")[0]
                print(f"✗ {pkg_name}: {e}")
        print("📦 Package preinstallation complete!")

else:
    # Non-Pyodide environment
    async def preinstall_packages():
        print("Not running in Pyodide environment - skipping preinstall")
        pass

