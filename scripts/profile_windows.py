"""Capture actual profile timeline through DevTools' VM Service HTTP protocol."""
import json
import os
import tempfile
from pathlib import Path
import subprocess
import sys
import time
sys.stdout.reconfigure(encoding='utf8')
sys.stderr.reconfigure(encoding='utf8')
import urllib.parse
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
def main():
    output=ROOT/'runtime/performance';output.mkdir(parents=True,exist_ok=True)
    log=(output/'profile-run.log').open('w',encoding='utf8')
    fixture=tempfile.TemporaryDirectory()
    backend_env=dict(os.environ,AUTH_TOKEN='performance-fixture-local',DATABASE_PATH=str(Path(fixture.name)/'fixture.db'),ACTIVE_PROVIDER='mock',API_ENABLED='false',HOST='127.0.0.1',PORT='8080')
    backend=subprocess.Popen([sys.executable,'-B','-X','utf8','-m','server.api.app'],cwd=ROOT,env=backend_env,stdout=log,stderr=subprocess.STDOUT)
    health_opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for attempt in range(40):
        if backend.poll() is not None:
            log.flush();raise RuntimeError('Mock backend exited: '+(output/'profile-run.log').read_text(encoding='utf8',errors='replace')[-3000:])
        try:
            with health_opener.open('http://127.0.0.1:8080/health',timeout=1) as response:
                if json.load(response).get('ok'):break
        except (OSError,ValueError):pass
        time.sleep(.25)
    else:raise TimeoutError('Mock backend not ready for timing probe')
    process=subprocess.Popen(['flutter.bat','run','-d','windows','--profile','--vm-service-port=8181','--disable-service-auth-codes','--dart-define=PERFORMANCE_PROBE=true'],cwd=ROOT/'client/flutter_app',stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.PIPE,shell=True)
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def request(method,**args):
        url='http://127.0.0.1:8181/'+method+'?'+urllib.parse.urlencode(args)
        with opener.open(url,timeout=40) as response:return json.load(response)
    try:
        deadline=time.monotonic()+600
        while time.monotonic()<deadline:
            if process.poll() is not None:raise RuntimeError('Profile Flutter exited: '+(output/'profile-run.log').read_text(encoding='utf8')[-4000:])
            try:
                vm=request('getVM');isolates=vm.get('result',vm)['isolates']
                main_isolate=next(i for i in isolates if i['name']=='main')
                details=request('getIsolate',isolateId=main_isolate['id']);details=details.get('result',details)
                if 'ext.xinghui.benchmark' in details.get('extensionRPCs',[]):break
            except (OSError,ValueError,KeyError,StopIteration):pass
            time.sleep(.5)
        else:raise TimeoutError('Profile VM Service not ready')
        request('setVMTimelineFlags',recordedStreams=json.dumps(['Dart','Embedder','GC']))
        request('clearVMTimeline')
        metrics=request('ext.xinghui.benchmark',isolateId=main_isolate['id'])
        metrics=metrics.get('result',metrics)
        timeline=request('getVMTimeline');timeline=timeline.get('result',timeline)
        (output/'performance-metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf8')
        (output/'devtools-timeline.json').write_text(json.dumps(timeline),encoding='utf8')
        if 'samples' not in metrics:
            raise RuntimeError('VM extension result: '+json.dumps(metrics,ensure_ascii=False)+'\n'+(output/'profile-run.log').read_text(encoding='utf8',errors='replace')[-6000:])
        assert metrics['samples']==40 and metrics['frames']>0,metrics
        assert metrics['typing_list_rebuilds']==0,metrics
        print(json.dumps(metrics,ensure_ascii=False),flush=True)
    finally:
        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True)
        subprocess.run(['taskkill','/IM','xinghui_companion.exe','/F'],capture_output=True)
        backend.terminate();backend.wait(timeout=15);fixture.cleanup()
        log.close()
if __name__=='__main__':
    try:main()
    except Exception:
        import traceback
        print('::error::'+traceback.format_exc().replace('%','%25').replace('\r','%0D').replace('\n','%0A'),flush=True);sys.exit(1)
