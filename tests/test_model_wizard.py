import io
import json
import os
import unittest
from dataclasses import replace
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.model_config import PROVIDERS, catalog, read_model_config
from server.providers import provider_for
from server.providers.cloud import ProviderError

class Response:
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def read(self,n):return json.dumps({'choices':[{'message':{'content':'连接成功'}}],'usage':{'prompt_tokens':3,'completion_tokens':2}}).encode()

class ModelWizardTests(unittest.TestCase):
    def setUp(self):
        self.environment=patch.dict(os.environ,{},clear=True);self.environment.start()
        self.app=Application(Config(database=':memory:',token='fixture',require_confirmation=False,max_daily_calls=100),Store(':memory:'))
    def tearDown(self):
        self.app.store.db.close();self.environment.stop()
    def request(self,method,path,body=None,token='fixture'):
        raw=json.dumps(body or {}).encode();result={}
        env={'REQUEST_METHOD':method,'PATH_INFO':path,'CONTENT_LENGTH':str(len(raw)),'HTTP_AUTHORIZATION':'Bearer '+token,'wsgi.input':io.BytesIO(raw)}
        output=json.loads(b''.join(self.app(env,lambda status,headers:result.update(code=int(status.split()[0])))))
        return result['code'],output
    def selected(self,name):
        data=catalog()[name]
        return {'provider':name,'base_url':data['base_url'],'model':data['models'][0],'api_key':'fixture-secret','paid_confirmed':not bool(data['free_models']),'api_enabled':True}
    def test_five_provider_requests_and_usage(self):
        for name in PROVIDERS:
            with self.subTest(provider=name),patch('server.providers.cloud.urlopen',return_value=Response()) as network:
                code,result=self.request('POST','/model/test',self.selected(name))
                self.assertEqual(code,200,result)
                request=network.call_args[0][0]
                self.assertEqual(request.full_url,catalog()[name]['base_url']+'/chat/completions')
                self.assertEqual(json.loads(request.data)['model'],catalog()[name]['models'][0])
        status=self.request('GET','/status')[1]
        self.assertEqual(status['today_model_calls'],5)
        self.assertEqual(status['today_model_tokens'],{'prompt_tokens':15,'completion_tokens':10})
    def test_wrong_key_and_platform_errors_redacted(self):
        for name in PROVIDERS:
            for code in (401,402,404,429):
                with self.subTest(provider=name,status=code),patch('server.providers.cloud.urlopen',side_effect=HTTPError('https://fixture.invalid',code,'fixture-secret',{},None)):
                    status,data=self.request('POST','/model/test',self.selected(name))
                    self.assertEqual(status,code,data)
                    self.assertIn(catalog()[name]['label'],data['error'])
                    self.assertNotIn('fixture-secret',json.dumps(self.request('GET','/status')[1]))
                    self.assertIn(str(code),data['error'])
        with patch('server.providers.cloud.urlopen',side_effect=URLError('fixture-secret')):
            self.assertEqual(self.request('POST','/model/test',self.selected('zhipu'))[0],503)
    def test_paid_gate_and_free_chat(self):
        paid=self.selected('deepseek');paid['paid_confirmed']=False
        self.assertIn('收费',self.request('POST','/model/test',paid)[1]['error'])
        free=self.selected('zhipu')
        with patch('server.model_service.persist_environment',side_effect=lambda values:os.environ.update(values)),patch('server.providers.cloud.urlopen',return_value=Response()):
            self.assertEqual(self.request('POST','/model/config',free)[0],200)
            code,out=self.request('POST','/chat',{'text':'你好'})
            self.assertEqual(code,200,out)
            self.assertEqual(out['provider'],'zhipu')
            self.assertFalse(self.app.config.allow_paid)
    def test_switch_keeps_keys_and_no_client_secrets(self):
        with patch('server.model_service.persist_environment',side_effect=lambda values:os.environ.update(values)):
            for name in ('zhipu','deepseek'):
                self.assertEqual(self.request('POST','/model/config',self.selected(name))[0],200)
            self.assertEqual(read_model_config('zhipu').api_key,'fixture-secret')
            config=self.request('GET','/model/config')[1]
            self.assertNotIn('fixture-secret',json.dumps(config))
            self.assertTrue(all(p['key_configured'] for p in config['providers'] if p['provider'] in ('zhipu','deepseek')))
            reuse=self.selected('zhipu');reuse['api_key']=''
            self.assertEqual(self.request('POST','/model/config',reuse)[0],200)
            self.assertEqual(read_model_config('deepseek').api_key,'fixture-secret')
        self.assertNotIn('fixture-secret',json.dumps(self.app.store.export_personal()))
    def test_settings_auth_format_and_save_failure_do_not_activate(self):
        self.assertEqual(self.request('GET','/model/config',token='wrong')[0],401)
        bad=self.selected('zhipu');bad['api_key']='line\nheader'
        self.assertEqual(self.request('POST','/model/config',bad)[0],400)
        with patch('server.model_service.persist_environment',side_effect=ValueError('Windows环境变量保存失败')):
            self.assertEqual(self.request('POST','/model/config',self.selected('zhipu'))[0],400)
        self.assertEqual(self.app.config.provider,'mock')
    def test_new_provider_factory_uses_environment(self):
        for name,refs in PROVIDERS.items():
            with patch.dict(os.environ,dict(zip(refs,('https://fixture.invalid','fixture-model','fixture-secret')))):
                self.assertEqual(provider_for(replace(self.app.config,provider=name)).name,name)
