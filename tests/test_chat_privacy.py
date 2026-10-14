import unittest
from tests import test_api
class ChatPrivacyTests(unittest.TestCase):
    def test_unsave_turn_removes_candidates_and_summary_but_preserves_approved_memory(self):
        api=test_api.ApiTests();api.setUp();self.addCleanup(api.tearDown)
        api.call('PATCH','/settings',{'save_conversations':True})
        row=api.create('/chat',{'text':'普通问候'})
        candidate=api.app.store.add('memory_candidate',{'source_turn_id':row['turn_id']})
        memory=api.create('/memories',{'content':'喜欢星空','consent':True})
        generation=api.app.store.generation
        self.assertEqual(api.call('DELETE','/conversations/'+row['turn_id'])[0],200)
        self.assertEqual(api.app.store.all('conversation_turn'),[])
        self.assertEqual(api.app.store.all('memory_candidate'),[])
        self.assertEqual(api.app.store.all('daily_summary')[0]['chat_topics'],[])
        self.assertEqual(api.app.store.get(memory['id'])['content'],'喜欢星空')
        self.assertGreater(api.app.store.generation,generation)
    def test_unsave_rejects_other_record_kind_and_status_never_exposes_key(self):
        import os
        from unittest.mock import patch
        from dataclasses import replace
        api=test_api.ApiTests();api.setUp();self.addCleanup(api.tearDown)
        memory=api.create('/memories',{'content':'喜欢星空','consent':True})
        self.assertEqual(api.call('DELETE','/conversations/'+memory['id'])[0],400)
        api.app.config=replace(api.app.config,provider='zhipu')
        with patch.dict(os.environ,{'ZHIPU_MODEL':'fixture-model','ZHIPU_API_KEY':'fixture-secret'}):
            result=api.call('GET','/status')[1]
        self.assertEqual(result['model'],'fixture-model');self.assertNotIn('fixture-secret',str(result))
