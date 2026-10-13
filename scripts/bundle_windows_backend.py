"""Package the hosted runner's verified CPython runtime for offline Windows use."""
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def bundle(destination):
    destination = Path(destination)
    backend = destination / 'backend'
    runtime = backend / 'python'
    runtime.mkdir(parents=True, exist_ok=True)
    source = Path(sys.base_prefix)
    for name in ('python.exe', 'pythonw.exe', 'python3.dll', 'python312.dll'):
        shutil.copy2(source / name, runtime / name)
    for dependency in source.glob('vcruntime*.dll'):
        shutil.copy2(dependency, runtime / dependency.name)
    shutil.copytree(source / 'DLLs', runtime / 'DLLs', dirs_exist_ok=True)
    with zipfile.ZipFile(runtime / 'python312.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in (source / 'Lib').rglob('*'):
            relative = path.relative_to(source / 'Lib')
            if path.is_file() and not any(part in {'site-packages', '__pycache__', 'test', 'tests', 'ensurepip', 'idlelib', 'tkinter'} for part in relative.parts):
                archive.write(path, str(relative))
    import tzdata
    shutil.copytree(Path(tzdata.__file__).parent, runtime / 'Lib/site-packages/tzdata',
                    ignore=shutil.ignore_patterns('__pycache__'), dirs_exist_ok=True)
    (runtime / 'python312._pth').write_text('python312.zip\nDLLs\nLib/site-packages\n..\nimport site\n', encoding='utf-8')
    shutil.copy2(source / 'LICENSE.txt', runtime / 'LICENSE.txt')
    shutil.copytree(ROOT / 'server', backend / 'server',
                    ignore=shutil.ignore_patterns('__pycache__'), dirs_exist_ok=True)
    (backend / 'scripts').mkdir(exist_ok=True)
    shutil.copy2(ROOT / 'scripts/local_backend.py', backend / 'scripts/local_backend.py')
    # Persona evaluation reads the synthetic policy fixtures from the project root.
    shutil.copytree(ROOT / 'data', backend / 'data', dirs_exist_ok=True)
    for name in ('start_backend.bat', 'enable_backend_autostart.bat', 'disable_backend_autostart.bat'):
        shutil.copy2(ROOT / name, destination / name)
    shutil.copy2(ROOT / 'docs/module-1-acceptance.md', destination / '模块一验收指南.md')


if __name__ == '__main__':
    bundle(sys.argv[1])
