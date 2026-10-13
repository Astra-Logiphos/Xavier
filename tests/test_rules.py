import unittest
from server.api.app import Application
from server.config import Config
from server.memory.store import Store

class RuleTests(unittest.TestCase):
    def setUp(self): self.app=Application(Config(token='fixture'),Store(':memory:'))
    def tearDown(self): self.app.store.db.close()
    def enable(self):
        self.app.store.set_setting('save_conversations',True)
        self.app.rules.update('interaction_learning',{'enabled':True})
    def test_learning_default_off_and_requires_consent(self):
        self.assertFalse(self.app.rules.get('interaction_learning')['enabled'])
        with self.assertRaises(ValueError): self.app.rules.update('interaction_learning',{'enabled':True})
        self.app.chat({'text':'我喜欢星空'})
        self.assertEqual(self.app.store.all('memory_candidate'),[])
    def test_extract_only_candidate_approve_then_retrieve(self):
        self.enable(); self.app.chat({'text':'我喜欢星空'})
        candidates=self.app.store.all('memory_candidate'); self.assertEqual(len(candidates),1)
        self.assertEqual(self.app.store.all('profile_memory'),[])
        result=self.app.rules.review_candidate(candidates[0]['id'],'approve')
        self.assertTrue(result['memory']['consent']); self.assertEqual(result['memory']['confidence'],1)
        self.assertEqual(result['memory']['extracted_confidence'],.6)
        with self.assertRaises(ValueError): self.app.rules.review_candidate(candidates[0]['id'],'approve')
    def test_no_save_and_sensitive_never_extract(self):
        self.enable()
        for body in [{'text':'我喜欢星空','no_save':True},{'text':'不要记住我喜欢星空'},{'text':'我喜欢密码 abc'}]: self.app.chat(body)
        self.assertEqual(self.app.store.all('memory_candidate'),[])
    def test_cannot_remove_review_gate(self):
        with self.assertRaises(ValueError): self.app.rules.update('interaction_learning',{'approval_required':False})
    def test_search_rule_task_reports_unverified(self):
        self.app.rules.update('persona_search',{'enabled':True,'keywords':['沈星回 性格']})
        task=self.app.rules.run_search(); self.assertEqual(task['status'],'awaiting_connector_authorization')
        self.assertEqual(self.app.store.all('source'),[])
    def test_candidate_never_modifies_canon(self):
        self.enable(); self.app.chat({'text':'我喜欢更主动的表达'})
        candidate=self.app.store.all('memory_candidate')[0]; self.app.rules.review_candidate(candidate['id'],'approve')
        self.assertEqual(self.app.persona.current()['snapshot']['canon'],[])
    def test_deletion_removes_candidate(self):
        self.enable(); self.app.chat({'text':'我喜欢星空'})
        candidate=self.app.store.all('memory_candidate')[0]
        memory=self.app.rules.review_candidate(candidate['id'],'approve')['memory']
        self.app.dispatch('DELETE','/memories/'+memory['id'],{}, {})
        self.assertEqual(self.app.store.all('memory_candidate'),[])
        self.assertEqual(self.app.store.all('profile_memory'),[])
