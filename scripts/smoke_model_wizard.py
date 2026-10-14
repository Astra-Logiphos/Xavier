import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from urllib.request import Request,urlopen

BOOTSTRAP = '''
import json,os
from urllib.error import HTTPError
from wsgiref.simple_server import make_server
import server.providers.cloud as cloud
from server.api.app import Application,ThreadedWSGIServer,PrivateHandler
class Response:
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def read(self,n):return json.dumps({'choices':[{'message':{'content':'fixture response'}}],'usage':{'prompt_tokens':3,'completion_tokens':2}}).encode()
def fixture(request,timeout):
    if 'bad-fixture' in request.get_header('Authorization',''):
        raise HTTPError(request.full_url,401,'fixture',{},None)
    return Response()
cloud.urlopen=fixture
app=Application()
with make_server('127.0.0.1',int(os.environ['XINGHUI_SMOKE_PORT']),app,server_class=ThreadedWSGIServer,handler_class=PrivateHandler) as server:server.serve_forever()
'''

def main():
    import socket,winreg
    from server.model_environment import ALLOWED,MARKER
    bundle=Path(sys.argv[1]).resolve()
    registry=winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER,'Environment',0,winreg.KEY_QUERY_VALUE|winreg.KEY_SET_VALUE)
    previous={}
    for name in ALLOWED|{MARKER}:
        try:previous[name]=winreg.QueryValueEx(registry,name)
        except FileNotFoundError:previous[name]=None
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
    process=None
    try:
        with tempfile.TemporaryDirectory() as temporary:
            env={k:v for k,v in os.environ.items() if k not in ALLOWED and k!=MARKER}
            env.update(AUTH_TOKEN='fixture-auth',DATABASE_PATH=str(Path(temporary)/'fixture.db'),XINGHUI_SMOKE_PORT=str(port),REQUIRE_API_CONFIRMATION='false')
            def call(method,path,body=None):
                request=Request(f'http://127.0.0.1:{port}'+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'Authorization':'Bearer fixture-auth','Content-Type':'application/json'})
                try:
                    with urlopen(request,timeout=4) as response:return response.status,json.loads(response.read())
                except __import__('urllib.error',fromlist=['HTTPError']).HTTPError as error:return error.code,json.loads(error.read())
            def start():
                child=subprocess.Popen([str(bundle/'backend/python/python.exe'),'-B','-X','utf8','-c',BOOTSTRAP],cwd=bundle/'backend',env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                deadline=time.monotonic()+15
                while time.monotonic()<deadline:
                    try:
                        if call('GET','/health')[0]==200:return child
                    except Exception:pass
                    if child.poll() is not None:raise AssertionError('fixture backend startup failed')
                    time.sleep(.1)
                child.terminate();child.wait(5)
                raise AssertionError('fixture backend startup timed out')
            process=start()
            data=call('GET','/model/config')[1]
            assert len(data['providers'])==5
            for selected in data['providers']:
                body={'provider':selected['provider'],'base_url':selected['base_url'],'model':selected['models'][0],'api_key':'fixture-only','paid_confirmed':not bool(selected['free_models']),'api_enabled':True}
                code,result=call('POST','/model/test',body);assert code==200,result
                code,result=call('POST','/model/config',body);assert code==200,result
            zhipu=next(p for p in data['providers'] if p['provider']=='zhipu')
            wrong={'provider':'zhipu','base_url':zhipu['base_url'],'model':zhipu['models'][0],'api_key':'bad-fixture'}
            code,result=call('POST','/model/test',wrong);assert code==401 and '401' in result['error'] and 'bad-fixture' not in result['error']
            before=call('GET','/model/config')[1]
            assert all(p['key_configured'] for p in before['providers'])
            process.terminate();process.wait(5);process=start()
            after=call('GET','/model/config')[1]
            assert after==before
            assert call('GET','/status')[1]['today_model_calls']==6
            assert 'fixture-only' not in json.dumps(call('GET','/data/export')[1])
            print('Native Windows five-provider registry save / stale-parent process restart / independent old keys / wrong-key 401 / usage / no backup secrets: PASS (external model transport mocked)')
    finally:
        if process is not None and process.poll() is None:process.terminate();process.wait(5)
        for name,value in previous.items():
            if value is None:
                try:winreg.DeleteValue(registry,name)
                except FileNotFoundError:pass
            else:winreg.SetValueEx(registry,name,0,value[1],value[0])
        registry.Close()

if __name__=='__main__':main()
