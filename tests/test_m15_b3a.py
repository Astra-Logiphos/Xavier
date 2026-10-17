"""m15-b3a 修复批验收：D5/D6/D9/D12/D13 门禁数据。"""
from datetime import datetime,timezone,timedelta
from dataclasses import replace
from unittest.mock import patch
import unittest
from server.api.app import Application,OVERVIEW_PATTERN,fallback_line
from server.config import Config
from server.memory.store import Store
from server.companion import CompanionService
from server.persona.core import compute_age,style_hits,core_card
from server.providers.base import LLMResult

class AgeTests(unittest.TestCase):
    def test_five_clock_cases(self):
        cases={'2024-11-01':24,'2026-10-15':25,'2026-10-17':26,'2027-03-01':26,'2027-10-17':27}
        for day,age in cases.items():
            self.assertEqual(compute_age(datetime.fromisoformat(day).date()),age,day)
    def test_anchor_2023_birthday_passed(self):
        self.assertEqual(compute_age(datetime(2023,10,16).date()),23)
        self.assertEqual(compute_age(datetime(2023,10,15).date()),22)

class GreetingDedupTests(unittest.TestCase):
    def setUp(self):
        self.app=Application(Config(database=':memory:',token='fixture'),Store(':memory:'))
        self.now=datetime(2026,10,14,10,tzinfo=timezone.utc)  # 18:00 本地，傍晚时段
        self.app.companion=CompanionService(self.app,lambda:self.now)
    def tearDown(self):self.app.store.db.close()
    def test_same_slot_three_opens_emit_once(self):
        service=self.app.companion
        for _ in range(3):
            events=service.tick({'event':'open','session_id':'s%d'%_})['events']
            self.assertEqual([e['type'] for e in events if e['type']=='greeting'],['greeting'] if _==0 else [])
        self.assertEqual(len([e for e in service.tick({'event':'open','session_id':'again'})['events'] if e['type']=='greeting']),0)
    def test_new_slot_next_day_emits_again(self):
        service=self.app.companion
        service.tick({'event':'open','session_id':'a'})
        self.now=datetime(2026,10,15,1,tzinfo=timezone.utc)  # 次日 09:00 本地，早晨时段
        events=service.tick({'event':'open','session_id':'b'})['events']
        self.assertEqual([e['type'] for e in events if e['type']=='greeting'],['greeting'])

class StyleGuardTests(unittest.TestCase):
    def test_break_character_regex(self):
        for text in ('作为一个人工智能，我不能吃。','我没有身体','先核对一下资料','住在你电脑里','不吃东西','我作为程序来回答'):
            self.assertIn('break_character',style_hits(text),text)
    def test_healthy_daily_reply_passes(self):
        self.assertEqual(style_hits('肉。早上的肉最香。'),[])
        self.assertEqual(style_hits('嗯……你觉得呢。'),[])
    def test_sentence_limit_relaxed_for_overview(self):
        text='。'.join(['记忆%d'%n for n in range(5)])+'。'
        self.assertEqual(style_hits(text,max_sentences=5),[])
        self.assertIn('sentence_limit',style_hits(text))
    def test_fallback_rotates_and_never_breaks_character(self):
        lines=core_card()['static']['fallback']
        self.assertIsInstance(lines,list)
        picked={fallback_line(datetime(2026,10,14,h,tzinfo=timezone.utc)) for h in range(6)}
        self.assertGreater(len(picked),1)
        for line in picked:self.assertEqual(style_hits(line),[])

class OverviewAndAlertTests(unittest.TestCase):
    def setUp(self):
        self.app=Application(Config(database=':memory:',token='fixture'),Store(':memory:'))
        self.app.config=replace(self.app.config,provider='zhipu',api_enabled=True,allow_paid=True)
        self.app.store.set_setting('cloud_api_allowed',True)
    def tearDown(self):self.app.store.db.close()
    def test_overview_question_injects_memories(self):
        for content in ('我上周去了海边','我养了一只猫叫团子','我在备考教师资格证'):
            self.app.memory({'kind':'profile_memory','content':content,'consent':True})
        captured=[]
        def complete(messages):captured.append(messages);return LLMResult('嗯，慢慢数。','zhipu','fixture')
        with patch('server.api.app.provider_for') as factory:
            factory.return_value.complete.side_effect=complete
            self.app.chat({'text':'我们的记忆有哪些？'})
            system=captured[0][0]['content']
            self.assertTrue(OVERVIEW_PATTERN.search('我们的记忆有哪些？'))
            for content in ('我上周去了海边','我养了一只猫叫团子','我在备考教师资格证'):
                self.assertIn(content,system)
    def test_two_consecutive_hits_record_alert(self):
        with patch('server.api.app.provider_for') as factory:
            provider=factory.return_value
            provider.complete.side_effect=[LLMResult('作为AI，我不能吃。','zhipu','fixture'),LLMResult('我没有身体，先核对一下资料。','zhipu','fixture')]
            answer=self.app.chat({'text':'你是谁'})['reply']
            self.assertEqual(provider.complete.call_count,2)
            self.assertIn(answer,core_card()['static']['fallback'])
        alerts=self.app.store.setting('style_violation_alerts')
        self.assertEqual(alerts[list(alerts)[0]]['count'],1)
        self.assertIn('break_character',alerts[list(alerts)[0]]['last_hits'])
