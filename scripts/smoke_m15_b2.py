"""Native Windows avatar process restarts and actual start_all BAT proof."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
def main():
    bundle=Path(sys.argv[1]).resolve()
    def execute(role,*args):
        prefix='--companion-avatar-smoke' if role=='companion' else '--avatar-smoke'
        subprocess.run([str(bundle/'xinghui_companion.exe'),prefix+args[0],*args[1:]],check=True,timeout=25)
        proof='companion-avatar-smoke.json' if role=='companion' else 'avatar-smoke.json'
        return json.loads((bundle/proof).read_text(encoding='utf8'))
    with tempfile.TemporaryDirectory() as temporary:
        source=Path(temporary)/'original.png';shutil.copy2(bundle/'data/flutter_assets/assets/characters/default.png',source)
        imported={role:execute(role,'-import',str(source)) for role in ('user','companion')}
        assert imported['user']['path']!=imported['companion']['path']
        source.unlink()
        for role,proof in imported.items():
            assert proof['exists'] and Path(proof['path']).parent==bundle/'config/avatars'
            assert execute(role,'-read')==proof
        assert execute('companion','-reset')['path'] is None
        assert not Path(imported['companion']['path']).exists()
        assert execute('user','-read')==imported['user']
        assert execute('user','-reset')['path'] is None
        assert not Path(imported['user']['path']).exists()
    for proof in ('avatar-smoke.json','companion-avatar-smoke.json'):(bundle/proof).unlink()
    print('Native BOTH avatars / original deletion / separate process reload / independent reset: PASS')
    with tempfile.TemporaryDirectory() as temporary:
        env=dict(os.environ,LOCALAPPDATA=temporary,APPDATA=temporary,XINGHUI_LAUNCH_SMOKE='1',XINGHUI_PATCH_TEST='1')
        output=bundle/'start-all-smoke.json';output.unlink(missing_ok=True)
        # Existing synthetic runner prefs may contain another token; remove the secure
        # access-token preference through the App's normal no-token autoconnect branch.
        logfile=Path(temporary)/'start-all.log'
        with logfile.open('w',encoding='utf8') as log:
            launcher=subprocess.Popen(['cmd.exe','/d','/c',str(bundle/'start_all.bat')],cwd=bundle,env=env,stdout=log,stderr=log)
            try:
                launcher.wait(timeout=65)
                assert launcher.returncode==0,logfile.read_text(encoding='utf8',errors='replace')
                deadline=time.monotonic()+30
                while not output.exists() and time.monotonic()<deadline:time.sleep(.25)
                proof=json.loads(output.read_text(encoding='utf8'));assert proof['connected'],proof
                assert (Path(temporary)/'XinghuiCompanion/backend/backend.pid').exists()
                print('Native start_all BAT: authenticated backend ready before App / App autoconnect PASS')
            finally:
                subprocess.run(['taskkill','/IM','xinghui_companion.exe','/F'],capture_output=True)
                stop_env=dict(os.environ,XINGHUI_TEST_PYTHON=str(bundle/'backend/python/python.exe'))
                subprocess.run(['powershell.exe','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $env:XINGHUI_TEST_PYTHON } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"],env=stop_env,capture_output=True)
                output.unlink(missing_ok=True)
    # Occupied port exposing an unrelated health endpoint must not start the App.
    from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
    import threading
    class ForeignService(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200 if self.path=='/health' else 401)
            self.end_headers();self.wfile.write(b'{"ok":true}')
        def log_message(self,*args):pass
    foreign=ThreadingHTTPServer(('127.0.0.1',8080),ForeignService)
    thread=threading.Thread(target=foreign.serve_forever,daemon=True);thread.start()
    try:
        with tempfile.TemporaryDirectory() as temporary:
            env=dict(os.environ,LOCALAPPDATA=temporary,APPDATA=temporary,XINGHUI_LAUNCH_SMOKE='1',XINGHUI_PATCH_TEST='1')
            result=subprocess.run(['cmd.exe','/d','/c',str(bundle/'start_all.bat')],cwd=bundle,env=env,capture_output=True,timeout=65)
            assert result.returncode!=0
            assert not (bundle/'start-all-smoke.json').exists()
            print('Native start_all occupied/unready port: timeout, App not started PASS')
    finally:foreign.shutdown();foreign.server_close();thread.join(5)

if __name__=='__main__':
    try:main()
    except Exception:
        import traceback
        sys.stdout.reconfigure(encoding='utf8')
        print('::error::'+traceback.format_exc().replace('%','%25').replace('\r','%0D').replace('\n','%0A'),flush=True)
        sys.exit(1)
