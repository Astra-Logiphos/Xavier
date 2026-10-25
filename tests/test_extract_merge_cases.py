"""阶段2：extract_cases 抽取与 merge_cases 门禁（不依赖网络、不碰真实文件）。"""
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.extract_cases import build_draft, parse_entries
from scripts import merge_cases


class ExtractCasesTests(unittest.TestCase):
    def test_pairs_and_blank_expect(self):
        lines = [
            json.dumps({'role': 'user', 'content': '今天有点累'}),
            json.dumps({'role': 'assistant', 'content': '先坐一会儿。'}),
            json.dumps({'role': 'user', 'content': {'text': '中午吃了肉'}}),
            json.dumps({'role': 'assistant', 'content': {'message': '肉啊，好选择。'}}),
            'not-json-line',
        ]
        draft, count = build_draft(parse_entries(lines))
        self.assertEqual(count, 2)
        self.assertIn('input: 今天有点累', draft)
        self.assertIn('actual: 肉啊，好选择。', draft)
        self.assertIn('expect_keywords: （待人工补）', draft)

    def test_missing_file_refused_without_scanning(self):
        from scripts.extract_cases import main
        with mock.patch('sys.argv', ['x', 'Z:/不存在/会话.jsonl']):
            with self.assertRaises(SystemExit):
                main()


class MergeCasesGateTests(unittest.TestCase):
    def setUp(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        original = json.loads(merge_cases.CASES.read_text(encoding='utf8'))
        self.cases_copy = tmp / 'cases.json'
        self.cases_copy.write_text(
            json.dumps(original, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
        self.filled = tmp / 'filled.json'
        self.patchers = [
            mock.patch.object(merge_cases, 'CASES', self.cases_copy),
            mock.patch.object(merge_cases, 'PROPOSAL', tmp / 'proposal.md'),
            mock.patch.object(merge_cases, 'CONFLICT_REPORT', tmp / 'conflict.md'),
            mock.patch.object(merge_cases, 'EVAL_REPORT', tmp / 'eval.md'),
        ]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_failing_batch_writes_conflict_and_skips_merge(self):
        self.filled.write_text(json.dumps([
            {'input': '测试', 'expect_keywords': ['绝不出现的词'],
             'expected_policy': '演示失败'}], ensure_ascii=False), encoding='utf8')
        with mock.patch('sys.argv', ['merge', str(self.filled)]):
            self.assertEqual(merge_cases.main(), 1)
        self.assertEqual(json.loads(self.cases_copy.read_text(encoding='utf8'))[0]['id'], 1)
        self.assertTrue(merge_cases.CONFLICT_REPORT.exists())
        self.assertFalse(merge_cases.PROPOSAL.exists())

    def test_success_path_appends_and_writes_proposal(self):
        self.filled.write_text(json.dumps([
            {'input': '你好呀', 'expect_keywords': ['嗯', '你'],
             'expected_policy': '日常问候'}], ensure_ascii=False), encoding='utf8')
        summary = {'passed': 1, 'total': 1, 'mode': 'real',
                   'static_guards_ok': True, 'provider': 'mock'}
        report = '| 1 | 问候 | real | 通过 | 日常问候 |\n'
        with mock.patch.object(merge_cases.runner, 'run',
                               return_value=(summary, report)) as run_mock:
            with mock.patch('sys.argv', ['merge', str(self.filled), '--real']):
                self.assertEqual(merge_cases.main(), 0)
        run_mock.assert_called_once()
        now = json.loads(self.cases_copy.read_text(encoding='utf8'))
        self.assertEqual(len(now), 11)
        self.assertEqual(now[0]['name'], '安慰用户')
        self.assertEqual(now[-1]['input'], '你好呀')
        self.assertTrue(merge_cases.PROPOSAL.exists())

    def test_regressed_reply_blocks_merge_even_if_keywords_hit(self):
        self.filled.write_text(json.dumps([
            {'input': '你好', 'expect_keywords': ['嗯'],
             'expected_policy': '演示回退'}], ensure_ascii=False), encoding='utf8')
        summary = {'passed': 1, 'total': 1, 'mode': 'real',
                   'static_guards_ok': True, 'provider': 'mock'}
        report = '| 1 | 问候 | real | 通过 | 演示回退；风格命中：sentence_limit |\n'
        with mock.patch.object(merge_cases.runner, 'run',
                               return_value=(summary, report)):
            with mock.patch('sys.argv', ['merge', str(self.filled), '--real']):
                self.assertEqual(merge_cases.main(), 1)
        self.assertEqual(len(json.loads(self.cases_copy.read_text(encoding='utf8'))), 10)


if __name__ == '__main__':
    unittest.main()
