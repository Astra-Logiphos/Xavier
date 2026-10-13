"""Exercise the actual packaged BAT, runtime, persistence and crash recovery."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request

bundle = Path(sys.argv[1]).resolve()
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def wait_health():
    for _ in range(60):
        try:
            with opener.open('http://127.0.0.1:8080/health', timeout=1) as response:
                if json.load(response)['ok']: return
        except (OSError, ValueError): pass
        time.sleep(0.5)
    raise RuntimeError('Packaged backend failed health readiness')


def request(method, path, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request('http://127.0.0.1:8080' + path, data=data,
                                 headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token}, method=method)
    with opener.open(req, timeout=5) as response: return json.load(response)


with tempfile.TemporaryDirectory() as temporary:
    env = dict(os.environ, LOCALAPPDATA=temporary, APPDATA=temporary)
    log_path = Path(temporary) / 'launcher.log'
    with log_path.open('w', encoding='utf-8') as log:
        def launch():
            return subprocess.Popen(['cmd.exe', '/d', '/c', str(bundle / 'start_backend.bat'), '--background'],
                                    cwd=bundle, env=env, stdout=log, stderr=log)
        process = launch()
        try:
            wait_health()
            token_file = Path(temporary) / 'XinghuiCompanion/backend/auth_token.txt'
            token = token_file.read_text().strip()
            assert request('POST', '/chat', token, {'text': '记住这件事：我喜欢星空'})['saved']
            assert len(request('GET', '/conversations', token)['items']) == 1
            memory = request('GET', '/memories', token)['items'][0]
            request('PATCH', '/memories/' + memory['id'], token, {'content': '我喜欢星空和鸟', 'consent': True})
            # Locate exactly the API child of this launcher's supervisor, then crash it.
            command = 'Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*server.api.app*" -and $_.Name -eq "python.exe" } | Select-Object -ExpandProperty ProcessId'
            child_ids = subprocess.check_output(['powershell', '-NoProfile', '-Command', command], text=True).split()
            assert len(child_ids) == 1, child_ids
            subprocess.run(['taskkill', '/PID', child_ids[0], '/F'], check=True)
            time.sleep(6)
            wait_health()
            assert request('GET', '/memories', token)['items'][0]['content'] == '我喜欢星空和鸟'
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], check=True)
            process.wait(timeout=10)
            process = launch()
            wait_health()
            assert token_file.read_text().strip() == token
            assert len(request('GET', '/conversations', token)['items']) == 1
            assert len(request('GET', '/memories', token)['items']) == 1
            request('DELETE', '/memories/' + memory['id'], token)
            assert request('GET', '/memories', token)['items'] == []
            for flag in ('--install-autostart', '--remove-autostart'):
                subprocess.run(['cmd.exe', '/d', '/c', str(bundle / 'start_backend.bat'), flag], env=env, check=True)
            assert not list(Path(temporary).rglob('XinghuiBackend.vbs'))
            print('Packaged BAT / token reuse / persistence / memory CRUD / crash recovery / startup registration: PASS')
        finally:
            if process.poll() is None:
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], check=False)
                process.wait(timeout=10)
            log.flush()
            print(log_path.read_text(encoding='utf-8', errors='replace'))
