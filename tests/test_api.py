import io
import json
import os
import unittest
from dataclasses import replace
from unittest.mock import patch
from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.persona.service import evaluate
from server.providers.cloud import DeepSeekProvider, ZhipuProvider
from server.providers import provider_for
from server.emotion.analyzer import EmotionAnalyzer
from server.voice.providers import emotion_params, MockTTSProvider, MockSTTProvider

class ApiTests(unittest.TestCase):
    def setUp(self):
        self.app=Application(Config(database=':memory:',token='test-token'),Store(':memory:'))
    def tearDown(self): self.app.store.db.close()
    def call(self,method,path,body=None,token='test-token'):
        url,_,query=path.partition('?'); raw=json.dumps(body or {}).encode(); meta={}
        env={'REQUEST_METHOD':method,'PATH_INFO':url,'QUERY_STRING':query,'CONTENT_LENGTH':str(len(raw)),
             'HTTP_AUTHORIZATION':'Bearer '+token,'wsgi.input':io.BytesIO(raw)}
        def start(status,headers): meta['status']=int(status.split()[0]); meta['headers']=dict(headers)
        out=json.loads(b''.join(self.app(env,start)))
        return meta['status'],out
    def create(self,path,body):
        code,row=self.call('POST',path,body); self.assertEqual(code,200,row); return row
    def test_auth_and_public_health(self):
        self.assertEqual(self.call('GET','/health',token='wrong')[0],200)
        self.assertEqual(self.call('GET','/memories',token='wrong')[0],401)
        self.app.config=replace(self.app.config,token='')
        self.assertEqual(self.call('POST','/chat',{'text':'你好'})[0],503)
    def test_safe_default_start(self):
        row=self.create('/chat',{'text':'你好'})
        self.assertIn('免费规则',row['reply']); self.assertFalse(row['saved'])
        self.assertEqual(self.app.store.all('conversation_turn'),[])
        status=self.call('GET','/status')[1]
        self.assertEqual(status['persona_version'],'persona-0001'); self.assertEqual(status['pending_sources'],0)
    def test_date_timezone_and_no_save(self):
        self.call('PATCH','/settings',{'save_conversations':True})
        row=self.create('/chat',{'text':'普通问候'})
        self.assertTrue(row['saved']); self.assertEqual(row['local_date'],self.app.local_date())
        row=self.create('/chat',{'text':'这句话不要记住 今天学了深度学习','save_learning':True})
        self.assertFalse(row['saved']); self.assertEqual(self.app.store.all('learning_memory'),[])
        self.assertEqual(len(self.app.store.all('conversation_turn')),1)
    def test_sensitive_not_automatic(self):
        self.call('PATCH','/settings',{'save_conversations':True})
        row=self.create('/chat',{'text':'我的密码是秘密'})
        self.assertFalse(row['saved'])
        self.assertEqual(self.call('POST','/memories',{'content':'密码 abc','consent':True})[0],400)
    def test_memory_consent_low_confidence_and_delete(self):
        self.assertEqual(self.call('POST','/memories',{'content':'喜欢蓝色'})[0],400)
        row=self.create('/memories',{'content':'喜欢蓝色','consent':True,'confidence':.4})
        self.assertEqual(row['review_status'],'pending_review')
        self.assertEqual(self.call('POST','/memories',{'content':'官方剧情','kind':'canon_persona','consent':True})[0],400)
        self.assertEqual(self.call('DELETE','/memories/'+row['id'])[0],200)
        self.assertEqual(self.call('GET','/memories')[1]['items'],[])
    def test_memory_chat_commands(self):
        row=self.create('/chat',{'text':'记住这件事：喜欢星空'})
        rid=row['action']['id']
        result=self.create('/chat',{'text':'忘记这件事','memory_id':rid})
        self.assertEqual(result['action'],'memory_deleted')
        self.assertEqual(self.call('GET','/memories')[1]['items'],[])
    def test_learning_recall_no_fabrication(self):
        reply=self.create('/chat',{'text':'上次学过深度学习吗'})['reply']; self.assertNotIn('上次我们学到',reply)
        self.create('/chat',{'text':'今天学了深度学习','save_learning':True})
        row=self.create('/chat',{'text':'上次学过深度学习吗'})
        self.assertIn('上次我们学到',row['reply'])
        self.assertEqual(len(self.app.store.all('learning_memory')),1)
    def test_learning_review_quiz(self):
        row=self.create('/learning',{'topic':'梯度下降','consent':True,'knowledge_points':['沿负梯度更新参数']})
        quiz=self.call('GET','/learning/'+row['id']+'/quiz')[1]
        self.assertEqual(len(quiz['questions']),1)
        review=self.create('/learning/'+row['id']+'/review',{})
        self.assertEqual(review['review_count'],1)
        daily=self.call('GET','/daily')[1]; self.assertIn('梯度下降',daily['summary']['learned'])
    def test_checkin_idempotent_backfill_streak(self):
        from datetime import date,timedelta
        today=self.app.local_date(); yesterday=(date.fromisoformat(today)-timedelta(days=1)).isoformat()
        a=self.create('/checkins',{'category':'学习','local_date':yesterday}); self.assertTrue(a['backfilled'])
        b=self.create('/checkins',{'category':'学习'}); self.assertEqual(b['streak'],2)
        self.create('/checkins',{'category':'学习'})
        self.assertEqual(len(self.app.store.all('checkin')),2)
    def source(self):
        return self.create('/sources',{'url':'https://example.org/post','title':'授权摘要','text':'我觉得他很温柔。可能更主动。剧情有这句话','platform':'manual'})
    def test_source_metadata_claim_split_and_minimal_text(self):
        row=self.source(); self.assertEqual(row['review_status'],'pending_review')
        types={r['claim_type'] for r in row['claims']}; self.assertEqual(types,{'opinion','speculation','fact'})
        self.assertNotIn('text',row); self.assertEqual(row['source_type'],'unverified')
        self.assertIn('未获取',row['notice']); self.assertEqual(self.call('POST','/search',{'keywords':['沈星回']})[0],400)
        self.assertEqual(len(self.call('GET','/sources?q=温柔&platform=manual')[1]['items']),1)
    def test_url_validation_no_fetch(self):
        for url in ['http://example.org','file:///etc/passwd','https://u:p@example.org']:
            self.assertEqual(self.call('POST','/sources',{'url':url,'title':'x'})[0],400)
    def test_review_source_before_trait(self):
        s=self.source()
        body={'text':'温柔','layer':'community_evidence','source_id':s['id']}
        self.assertEqual(self.call('POST','/traits',body)[0],400)
        self.create('/review',{'id':s['id'],'action':'approve'})
        t=self.create('/traits',body)
        v=self.create('/review',{'id':t['id'],'action':'approve'})['version']
        self.assertEqual(v['status'],'active'); self.assertEqual(len(v['approved_community_evidence']),1)
        self.assertEqual(v['snapshot']['canon'],[])
        self.create('/review',{'id':s['id'],'action':'reject'})
        self.assertEqual(self.app.persona.current()['approved_community_evidence'],[])
    def test_canon_requires_provenance_and_version(self):
        s=self.source(); self.create('/review',{'id':s['id'],'action':'approve'})
        t=self.create('/traits',{'text':'官方事实','layer':'canon_persona','source_id':s['id']})
        self.assertEqual(self.call('POST','/review',{'id':t['id'],'action':'approve'})[0],400)
        self.call('PATCH','/sources/'+s['id'],{'source_type':'official','source_version':'user-verified-v1'})
        t=self.create('/traits',{'text':'用户核对过的剧情摘要','layer':'canon_persona','source_id':s['id']})
        self.create('/review',{'id':t['id'],'action':'approve'})
        self.assertEqual(len(self.app.persona.current()['snapshot']['canon']),1)
    def test_preference_pause_diff_rollback_delete(self):
        initial=self.app.persona.current()
        t=self.create('/traits',{'text':'更温柔','layer':'user_preference'})
        v=self.create('/review',{'id':t['id'],'action':'approve'})['version']
        self.assertIn(t['id'],v['active_user_preferences'])
        self.call('PATCH','/traits/'+t['id'],{'paused':True})
        self.assertEqual(self.app.persona.current()['active_user_preferences'],[])
        rollback=self.create('/persona/rollback',{'id':v['id']})
        self.assertIn(t['id'],rollback['active_user_preferences'])
        code,delta=self.call('GET','/persona/diff?left='+initial['id']+'&right='+v['id'])
        self.assertEqual(code,200); self.assertTrue(delta['diff'])
        self.call('DELETE','/traits/'+t['id'])
        self.assertNotIn('更温柔',self.call('GET','/persona/export')[1]['markdown'])
        self.create('/persona/rollback',{'id':v['id']})
        self.assertEqual(self.app.persona.current()['active_user_preferences'],[])
    def test_conflicts_block_approval(self):
        t=self.create('/traits',{'text':'更主动','possible_conflicts':['与克制范围冲突']})
        self.assertEqual(self.call('POST','/review',{'id':t['id'],'action':'approve'})[0],400)
    def test_daily_and_emotion_correction(self):
        self.call('PATCH','/settings',{'save_conversations':True})
        t=self.create('/chat',{'text':'我有点累'})
        result=self.call('PATCH','/emotion/'+t['turn_id'],{'label':'calm'})[1]
        self.assertEqual(result['emotion']['method'],'user_corrected')
        self.assertEqual(len(self.call('GET','/daily')[1]['turns']),1)
    def test_model_fail_closed(self):
        self.app.config=replace(self.app.config,provider='deepseek')
        self.assertEqual(self.call('POST','/chat',{'text':'你好'})[0],400)
        self.app.config=replace(self.app.config,api_enabled=True)
        self.assertIn('确认',self.call('POST','/chat',{'text':'你好'})[1]['error'])
        self.assertIn('收费',self.call('POST','/chat',{'text':'你好','api_confirmed':True})[1]['error'])
        self.app.config=replace(self.app.config,allow_paid=True,max_daily_calls=0)
        self.assertIn('上限',self.call('POST','/chat',{'text':'你好','api_confirmed':True})[1]['error'])
    def test_no_key_start_and_call_safe_message(self):
        with patch.dict(os.environ,{'DEEPSEEK_API_KEY':'','DEEPSEEK_MODEL':''}):
            self.app.config=replace(self.app.config,provider='deepseek',api_enabled=True,allow_paid=True)
            self.assertEqual(self.call('GET','/health')[0],200)
            result=self.call('POST','/chat',{'text':'你好','api_confirmed':True})
            self.assertIn('未配置',result[1]['error'])
    def test_mock_voice_and_settings(self):
        out=self.create('/voice/tts',{'text':'你好'}); self.assertIsNone(out['audio_url'])
        self.call('PATCH','/settings',{'voice_enabled':True})
        out=self.create('/voice/tts',{'text':'你好','emotion':'tired'})
        self.assertTrue(out['mock']); self.assertLess(out['params']['speed'],1)
        self.assertTrue(self.create('/voice/stt',{'text_fixture':'你好'})['mock'])
    def test_export_and_total_delete(self):
        self.create('/memories',{'content':'喜欢星空','consent':True})
        self.create('/traits',{'text':'更主动'})
        self.assertTrue(self.call('GET','/data/export')[1]['records'])
        self.assertEqual(self.call('DELETE','/data')[0],400)
        self.assertEqual(self.call('DELETE','/data',{'confirmation':'DELETE_ALL'})[0],200)
        rows=self.app.store.all(); self.assertEqual(len(rows),1); self.assertEqual(rows[0]['kind'],'persona_version')
        self.assertEqual(self.app.persona.current()['active_user_preferences'],[])
    def test_invalid_input_and_no_detail_leak(self):
        self.assertEqual(self.call('POST','/chat',{'text':1})[0],400)
        self.assertEqual(self.call('POST','/checkins',{'category':'学习','local_date':'bad'})[0],400)
        self.assertEqual(self.call('PATCH','/settings',{'save_conversations':'false'})[0],400)
        self.assertEqual(self.call('GET','/does-not-exist')[0],404)

class ProviderTests(unittest.TestCase):
    def test_cloud_contract_without_network(self):
        class Response:
            def __enter__(self): return self
            def __exit__(self,*args): pass
            def read(self,n): return json.dumps({'choices':[{'message':{'content':'模拟服务响应'}}]}).encode()
        for cls,prefix in [(DeepSeekProvider,'DEEPSEEK'),(ZhipuProvider,'ZHIPU')]:
            with self.subTest(cls=cls.__name__), patch.dict(os.environ,{prefix+'_API_KEY':'test-fixture',prefix+'_MODEL':'fixture-model'}), patch('server.providers.cloud.urlopen',return_value=Response()) as call:
                result=cls().complete([{'role':'user','content':'fixture'}])
                self.assertEqual(result.text,'模拟服务响应')
                sent=json.loads(call.call_args.args[0].data)
                self.assertEqual(sent['model'],'fixture-model')
    def test_ollama_disabled(self):
        with self.assertRaises(ValueError): provider_for(Config(provider='ollama'))
    def test_emotion_and_voice(self):
        self.assertEqual(EmotionAnalyzer().analyze('我累了')['label'],'tired')
        self.assertEqual(EmotionAnalyzer().analyze('我累了',False)['confidence'],0)
        p=emotion_params('sad','ja-JP')
        self.assertIsNone(MockTTSProvider().synthesize('fixture',p)['audio_url'])
        self.assertEqual(MockSTTProvider().transcribe('fixture',p)['text'],'fixture')

if __name__=='__main__': unittest.main()
