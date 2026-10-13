import io
import json
import unittest
from server.api.app import Application
from server.config import Config
from server.memory.store import Store

class SecurityRegression(unittest.TestCase):
    def setUp(self): self.app=Application(Config(token='fixture'),Store(':memory:'))
    def tearDown(self): self.app.store.db.close()
    def test_no_save_flag_does_not_save_learning_or_preference(self):
        for text in ['今天学了深度学习','我希望你更主动','记住这件事：喜欢蓝色']:
            out=self.app.chat({'text':text,'no_save':True,'save_learning':True})
            self.assertFalse(out['saved'])
        self.assertEqual(self.app.store.all('learning_memory'),[])
        self.assertEqual(self.app.store.all('trait'),[])
        self.assertEqual(self.app.store.all('profile_memory'),[])
    def test_source_revocation_not_resurrected_by_rollback(self):
        s=self.app.dispatch('POST','/sources',{'title':'fixture','url':'https://example.org/fixture','text':'我觉得温柔'}, {})
        self.app.dispatch('POST','/review',{'id':s['id'],'action':'approve'}, {})
        t=self.app.dispatch('POST','/traits',{'text':'温柔','layer':'community_evidence','source_id':s['id']}, {})
        out=self.app.dispatch('POST','/review',{'id':t['id'],'action':'approve'}, {})
        self.app.dispatch('POST','/review',{'id':s['id'],'action':'reject'}, {})
        self.app.persona.rollback(out['version']['id'])
        self.assertEqual(self.app.persona.current()['approved_community_evidence'],[])
    def test_disputed_source_is_removed_from_active_persona(self):
        s=self.app.dispatch('POST','/sources',{'title':'fixture','url':'https://example.org/fixture','text':'观点'}, {})
        self.app.dispatch('POST','/review',{'id':s['id'],'action':'approve'}, {})
        t=self.app.dispatch('POST','/traits',{'text':'温柔','layer':'community_evidence','source_id':s['id']}, {})
        self.app.dispatch('POST','/review',{'id':t['id'],'action':'approve'}, {})
        self.assertEqual(len(self.app.persona.current()['approved_community_evidence']),1)
        self.app.dispatch('PATCH','/sources/'+s['id'],{'evidence_status':'disputed'}, {})
        self.assertEqual(self.app.persona.current()['approved_community_evidence'],[])
    def test_request_size_and_json_types(self):
        for size,raw,expected in [('70000',b'{}',413),('2',b'[]',400),('1',b'{',400)]:
            meta={}
            def start(status,headers): meta['code']=int(status.split()[0])
            env={'PATH_INFO':'/chat','REQUEST_METHOD':'POST','CONTENT_LENGTH':size,
                 'HTTP_AUTHORIZATION':'Bearer fixture','wsgi.input':io.BytesIO(raw)}
            json.loads(b''.join(self.app(env,start)))
            self.assertEqual(meta['code'],expected)
    def test_rejected_source_never_becomes_canon(self):
        s=self.app.dispatch('POST','/sources',{'title':'fixture','url':'https://example.org/fixture','text':'剧情'}, {})
        self.app.dispatch('PATCH','/sources/'+s['id'],{'source_type':'official','source_version':'v1'}, {})
        self.app.dispatch('POST','/review',{'id':s['id'],'action':'approve'}, {})
        t=self.app.dispatch('POST','/traits',{'text':'测试摘要','layer':'canon_persona','source_id':s['id']}, {})
        self.app.dispatch('POST','/review',{'id':t['id'],'action':'approve'}, {})
        self.app.dispatch('PATCH','/sources/'+s['id'],{'source_type':'unreliable'}, {})
        self.assertEqual(self.app.persona.current()['snapshot']['canon'],[])
