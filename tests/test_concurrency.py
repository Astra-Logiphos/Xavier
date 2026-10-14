import json
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from urllib.request import Request, build_opener, ProxyHandler
from urllib.error import HTTPError
from unittest.mock import patch
from wsgiref.simple_server import make_server
from server.api.app import Application, ThreadedWSGIServer, PrivateHandler
from server.config import Config
from server.memory.store import Store
from server.providers.base import LLMResult

class ConcurrencyTests(unittest.TestCase):
    def setUp(self):
        self.app=Application(Config(database=':memory:',token='fixture',provider='zhipu',api_enabled=True,allow_paid=True),Store(':memory:'))
        self.app.store.set_setting('save_conversations',True)
        self.server=make_server('127.0.0.1',0,self.app,server_class=ThreadedWSGIServer,handler_class=PrivateHandler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        # Reuse the HTTP client as the App does; exclude Windows TLS certificate-store initialization.
        self.opener=build_opener(ProxyHandler({}))
        self.entered=threading.Event();self.release=threading.Event()
    def tearDown(self):
        self.release.set();self.server.shutdown();self.server.server_close();self.thread.join();self.app.store.db.close()
    def request(self,path,body=None,method=None):
        request=Request(f'http://127.0.0.1:{self.server.server_port}'+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'Authorization':'Bearer fixture','Content-Type':'application/json'})
        try:
            with self.opener.open(request,timeout=10) as response:return response.status,json.load(response)
        except HTTPError as error:return error.code,json.load(error)
    def slow(self,messages):
        self.assertFalse(self.app.store.lock._is_owned())
        self.entered.set();self.assertTrue(self.release.wait(8))
        return LLMResult('模拟慢回复','zhipu','fixture')
    def pending(self,pool):
        task=pool.submit(self.request,'/chat',{'text':'等待模型','api_confirmed':True})
        self.assertTrue(self.entered.wait(3));return task
    def test_status_under_100ms_while_llm_pending(self):
        with patch('server.api.app.provider_for') as provider,ThreadPoolExecutor(2) as pool:
            provider.return_value.complete.side_effect=self.slow
            task=self.pending(pool);times=[]
            try:
                for _ in range(5):
                    start=time.perf_counter();code,_=self.request('/status');times.append((time.perf_counter()-start)*1000)
                    self.assertEqual(code,200);self.assertFalse(task.done());self.assertLess(times[-1],100)
                print('CONCURRENCY_STATUS_MS '+json.dumps({'samples':times,'mean':sum(times)/len(times),'worst':max(times)},sort_keys=True),flush=True)
            finally:self.release.set()
            self.assertEqual(task.result()[0],200)
    def test_clear_during_llm_does_not_resurrect_data(self):
        with patch('server.api.app.provider_for') as provider,ThreadPoolExecutor(2) as pool:
            provider.return_value.complete.side_effect=self.slow;task=self.pending(pool)
            try:self.assertEqual(self.request('/data',{'confirmation':'DELETE_ALL'},'DELETE')[0],200)
            finally:self.release.set()
            self.assertEqual(task.result()[0],409);self.assertEqual(self.app.store.all('conversation_turn'),[])
    def test_restore_during_llm_discards_stale_completion(self):
        snapshot=self.app.store.export_personal()
        with patch('server.api.app.provider_for') as provider,ThreadPoolExecutor(2) as pool:
            provider.return_value.complete.side_effect=self.slow;task=self.pending(pool)
            try:self.assertEqual(self.request('/data/import',snapshot)[0],200)
            finally:self.release.set()
            self.assertEqual(task.result()[0],409);self.assertEqual(self.app.store.all('conversation_turn'),[])
    def test_opt_out_during_llm_prevents_save(self):
        with patch('server.api.app.provider_for') as provider,ThreadPoolExecutor(2) as pool:
            provider.return_value.complete.side_effect=self.slow;task=self.pending(pool)
            try:self.assertEqual(self.request('/settings',{'save_conversations':False},'PATCH')[0],200)
            finally:self.release.set()
            code,result=task.result();self.assertEqual(code,200);self.assertFalse(result['saved'])
    def test_review_publish_is_atomic_to_status_reader(self):
        code,trait=self.request('/traits',{'text':'温柔一点','layer':'user_preference'});self.assertEqual(code,200)
        original=self.app.persona.publish
        def paused(*args,**kwargs):
            self.entered.set();self.assertTrue(self.release.wait(8));return original(*args,**kwargs)
        with patch.object(self.app.persona,'publish',side_effect=paused),ThreadPoolExecutor(2) as pool:
            review=pool.submit(self.request,'/review',{'id':trait['id'],'action':'approve'})
            self.assertTrue(self.entered.wait(3));status=pool.submit(self.request,'/status')
            try:
                time.sleep(.03);self.assertFalse(status.done())
            finally:self.release.set()
            code,result=review.result();self.assertEqual(code,200)
            self.assertEqual(status.result()[1]['persona_version'],result['version']['version_id'])
