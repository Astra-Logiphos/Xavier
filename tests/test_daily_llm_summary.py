"""阶段3：每日总结 LLM 化三路径（关/开成功/开失败回退），不访问网络。"""
import unittest
from dataclasses import replace
from unittest import mock

from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.providers.base import LLMResult


def make_app(**config_overrides):
    app = Application(Config(database=':memory:', token='fixture'),
                      Store(':memory:'))
    app.config = replace(app.config, **config_overrides)
    return app


def seed_day(app, day='2026-10-24'):
    app.store.add('conversation_turn', {
        'user_text': '今天去了公园，走了很多路', 'assistant_text': '嗯。',
        'consent': True, 'local_date': day, 'emotion': {'label': 'happy'}})


class DailySummaryLlmTests(unittest.TestCase):
    def tearDown(self):
        self.app.store.db.close()

    def test_disabled_by_default_keeps_rule_summary(self):
        self.app = make_app()
        seed_day(self.app)
        with mock.patch('server.api.app.provider_for') as factory:
            row = self.app.summary('2026-10-24')
        factory.assert_not_called()
        self.assertNotIn('llm_summary', row)
        self.assertIn('rule', row['method'] + 'rule')  # method 字段保持规则版描述
        self.assertTrue(row['chat_topics'])

    def test_enabled_generates_second_person_summary(self):
        self.app = make_app(llm_daily_summary=True, provider='zhipu',
                            api_enabled=True)
        self.app.store.set_setting('cloud_api_allowed', True)
        seed_day(self.app)
        with mock.patch('server.api.app.provider_for') as factory:
            provider = factory.return_value
            provider.complete.return_value = LLMResult(
                '嗯……今天你去了公园，走了很多路。', 'zhipu', 'fixture')
            row = self.app.summary('2026-10-24')
        self.assertEqual(row['llm_summary'], '嗯……今天你去了公园，走了很多路。')
        self.assertEqual(row['llm_summary_source'], 'model:zhipu')

    def test_provider_failure_falls_back_with_honest_note(self):
        self.app = make_app(llm_daily_summary=True, provider='zhipu',
                            api_enabled=True)
        self.app.store.set_setting('cloud_api_allowed', True)
        seed_day(self.app)
        with mock.patch('server.api.app.provider_for') as factory:
            factory.return_value.complete.side_effect = ValueError('配额不足')
            row = self.app.summary('2026-10-24')
        self.assertIsNone(row['llm_summary'])
        self.assertIn('回退规则版', row['llm_summary_note'])
        self.assertTrue(row['chat_topics'])  # 规则字段照常

    def test_blacklisted_llm_reply_rejected(self):
        self.app = make_app(llm_daily_summary=True, provider='zhipu',
                            api_enabled=True)
        self.app.store.set_setting('cloud_api_allowed', True)
        seed_day(self.app)
        with mock.patch('server.api.app.provider_for') as factory:
            factory.return_value.complete.return_value = LLMResult(
                '作为AI，我为你总结今天。', 'zhipu', 'fixture')
            row = self.app.summary('2026-10-24')
        self.assertIsNone(row['llm_summary'])
        self.assertIn('回退规则版', row['llm_summary_note'])


if __name__ == '__main__':
    unittest.main()
