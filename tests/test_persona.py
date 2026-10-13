import json
import unittest
from pathlib import Path
from server.persona.service import BASE_PROMPT, evaluate
from server.api.app import Application
from server.config import Config
from server.memory.store import Store

class PersonaRegression(unittest.TestCase):
    def test_policy_gate_rejects_unverified_canon(self):
        snap={'canon':[{'source_type':'community','source_url':'','source_version':'','review_status':'approved'}],
              'community':[],'preferences':[],'styles':[],'prompt':BASE_PROMPT}
        self.assertFalse(evaluate(snap)['passed'])
    def test_ten_cases_have_behavior_checks(self):
        cases=json.loads(Path('data/sample/persona_eval_cases.json').read_text())
        self.assertEqual(len(cases),10)
        app=Application(Config(token='fixture'),Store(':memory:'))
        try:
            for case in cases:
                q=case['input']
                result=app.chat({'text':q,'mode':'professional' if case['id']==4 else 'chat'})
                with self.subTest(case=case['name']):
                    self.assertTrue(result['reply'])
                    self.assertNotIn('我是真人',result['reply'])
                    self.assertFalse(result['saved'])
                    self.assertEqual(app.persona.current()['snapshot']['canon'],[])
                    if case['id']==4: self.assertIn('无法验证',result['reply'])
                    if case['id']==7: self.assertNotIn('上次我们学到',result['reply'])
                    if case['id']==9: self.assertIn('选择',result['reply'])
                    if case['id']==10: self.assertEqual(result['action'],'no_save')
        finally: app.store.db.close()

class EvolutionGuardTests(unittest.TestCase):
    def test_conflicting_identity_preference_blocks_activation(self):
        from server.persona.service import PersonaService
        store=Store(':memory:'); persona=PersonaService(store); old=persona.current()['id']
        store.add('trait',{'text':'你是真人','layer':'user_preference','review_status':'approved','explicit':True,'possible_conflicts':[]})
        version=persona.publish('非法身份变更')
        self.assertEqual(version['status'],'blocked'); self.assertEqual(persona.current()['id'],old)
        store.db.close()
    def test_explicit_chat_request_creates_preference_candidate(self):
        app=Application(Config(token='fixture'),Store(':memory:'))
        result=app.chat({'text':'我希望你更主动'})
        self.assertEqual(result['action']['layer'],'user_preference')
        self.assertEqual(result['action']['review_status'],'pending_review')
        self.assertEqual(app.persona.current()['active_user_preferences'],[])
        app.store.db.close()
