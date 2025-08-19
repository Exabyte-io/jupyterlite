"""
Utils package for JupyterLite with automatic package installation
"""
import sys

# Auto-start package installation when utils is imported
if sys.platform == "emscripten":
    try:
        import asyncio
        import micropip
        
        async def install_packages_simple():
            print("🔧 Utils loaded - installing packages...")
            await micropip.install("mat3ra-api-examples", deps=False)
            await micropip.install("mat3ra-utils")
            
            from mat3ra.utils.jupyterlite.packages import install_packages
            await install_packages("")
            
            print("✅ Package installation complete!")
        
        # Start installation in background
        asyncio.create_task(install_packages_simple())
        
    except Exception as e:
        print(f"⚠️ Auto-installer failed: {e}")
        print("💡 Manual install: import micropip; await micropip.install('mat3ra-utils')")
else:
    # Standard Python environment
    pass
