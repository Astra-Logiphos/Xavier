import unittest
from server.api.app import Application
from server.config import Config
from server.memory.store import Store
class DailyTests(unittest.TestCase):
    def setUp(self): self.app=Application(Config(token='fixture'),Store(':memory:'))
    def tearDown(self): self.app.store.db.close()
    def test_daily_fields_preserve_evidence_and_uncertainty(self):
        self.app.store.set_setting('save_conversations',True)
        out=self.app.chat({'text':'今天完成练习。明天要复习。下次继续深度学习。我喜欢星空'})
        summary=self.app.summary(self.app.local_date())
        for key in ['events','unfinished_topics','promises_and_todos','preference_candidates']:
            self.assertEqual(len(summary[key]),1)
            self.assertEqual(summary[key][0]['source_turn_id'],out['turn_id'])
            self.assertEqual(summary[key][0]['status'],'candidate')
            self.assertLess(summary[key][0]['confidence'],.8)
    def test_unstored_chat_never_enters_daily_summary(self):
        self.app.chat({'text':'今天完成练习。明天要复习','no_save':True})
        summary=self.app.summary(self.app.local_date())
        self.assertEqual(summary['events'],[])
        self.assertEqual(summary['promises_and_todos'],[])
