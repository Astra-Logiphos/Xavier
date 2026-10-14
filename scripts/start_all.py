"""One-click local Windows launcher; never opens the App before health is ready."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request
ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT.parent if ROOT.name == 'backend' else ROOT

def wait_ready(check, timeout=45, clock=time.monotonic, pause=time.sleep):
    deadline = clock() + timeout
    while clock() < deadline:
        if check(): return
        pause(.25)
    raise TimeoutError('本地后端未就绪，App未启动。请检查8080端口及本地backend.log。')

def launch(install=INSTALL):
    install = Path(install)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    data = Path(os.environ['LOCALAPPDATA']) / 'XinghuiCompanion/backend'
    def ready():
        try:
            token = (data / 'auth_token.txt').read_text(encoding='utf8').strip()
            if len(token) < 32: return False
            request = urllib.request.Request('http://127.0.0.1:8080/status', headers={'Authorization': 'Bearer ' + token})
            with opener.open(request, timeout=1) as response:
                status = json.load(response)
                return 'provider' in status and 'persona_version' in status
        except (OSError, ValueError): return False
    if not ready():
        command = '"' + os.environ['COMSPEC'] + '" /d /s /c ""' + str(install / 'start_backend.bat') + '" --background"'
        subprocess.Popen(command, cwd=install,
                         creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
    wait_ready(ready)
    app = install / 'xinghui_companion.exe'
    if not app.is_file(): raise FileNotFoundError('安装目录缺少xinghui_companion.exe，请检查底座和补丁链。')
    subprocess.Popen([str(app)], cwd=install)
    print('本地后端已就绪，App已启动。', flush=True)

if __name__ == '__main__':
    try: launch()
    except Exception as error:
        print(str(error), flush=True)
        sys.exit(1)
