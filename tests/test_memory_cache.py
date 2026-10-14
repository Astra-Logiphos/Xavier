import threading
import unittest
from unittest.mock import patch
from server.memory.store import Store
from server.memory.retriever import MemoryRetriever
from server.api.app import Application
from server.config import Config

class MemoryCacheTests(unittest.TestCase):
    def setUp(self):
        self.store=Store(':memory:');self.addCleanup(self.store.db.close)
        self.now=0
        self.retriever=MemoryRetriever(self.store,clock=lambda:self.now)
    def memory(self,text='备考很烦'):
        return self.store.add('profile_memory',{'content':text,'consent':True,'review_status':'approved','confidence':1})
    def test_cache_and_five_minute_expiry(self):
        self.memory()
        with patch.object(self.store,'all',wraps=self.store.all) as read:
            self.assertTrue(self.retriever.retrieve('还记得备考'))
            self.retriever.retrieve('还记得备考');self.now=299;self.retriever.retrieve('备考')
            self.assertEqual(read.call_count,1)
            self.now=300;self.retriever.retrieve('备考');self.assertEqual(read.call_count,2)
    def test_edits_deletes_and_consent_revoke_immediately_invalidate(self):
        row=self.memory();self.assertTrue(self.retriever.retrieve('备考'))
        self.store.update(row['id'],{'content':'杨桃'});self.assertFalse(self.retriever.retrieve('备考'))
        self.assertTrue(self.retriever.retrieve('杨桃'))
        self.store.update(row['id'],{'consent':False});self.assertFalse(self.retriever.retrieve('杨桃'))
        self.store.update(row['id'],{'consent':True});self.store.delete(row['id']);self.assertFalse(self.retriever.retrieve('杨桃'))
    def test_clear_does_not_reuse_snapshot(self):
        self.memory();self.retriever.retrieve('备考');self.store.erase_personal()
        self.assertFalse(self.retriever.retrieve('备考'))
    def test_non_memory_writes_keep_cache(self):
        self.memory();self.retriever.retrieve('备考')
        with patch.object(self.store,'all',wraps=self.store.all) as read:
            self.store.add('conversation_turn',{'user_text':'备考'})
            self.retriever.retrieve('备考');read.assert_not_called()
    def test_ranking_does_not_hold_request_lock(self):
        import server.memory.retriever as module
        self.memory();self.retriever.retrieve('备考')
        blocked=threading.Event();release=threading.Event()
        original=module.tokens
        def slow(text):
            blocked.set();release.wait(2);return original(text)
        with patch.object(module,'tokens',side_effect=slow):
            worker=threading.Thread(target=lambda:self.retriever.retrieve('备考'))
            worker.start();self.assertTrue(blocked.wait(1))
            acquired=self.store.lock.acquire(timeout=.05)
            if acquired:self.store.lock.release()
            release.set();worker.join(2);self.assertTrue(acquired)
    def test_app_reuses_index_without_prompt_changes(self):
        app=Application(Config(),self.store);self.memory()
        with patch.object(app.retriever,'retrieve_with_revision',wraps=app.retriever.retrieve_with_revision) as retrieve:
            self.assertIn('备考',app.chat({'text':'还记得备考'})['reply'])
            self.assertEqual(retrieve.call_count,1)
