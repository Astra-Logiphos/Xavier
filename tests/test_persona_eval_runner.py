"""persona_eval runner 静态路径与产物检查（不依赖网络与 Key）。"""
import re
import tempfile
import unittest
from pathlib import Path

from server.persona_eval import runner


class RunnerStaticTests(unittest.TestCase):
    def test_static_run_passes_and_writes_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'persona_eval_report.md'
            summary, report = runner.run(real=False, output=output)
            self.assertTrue(output.exists())
            self.assertEqual(summary['mode'], 'static')
            self.assertTrue(summary['static_guards_ok'])
            self.assertEqual(summary['passed'], summary['total'])
            for name in ('安慰用户', '删除记忆', '不记录'):
                self.assertIn(name, report)
            self.assertIn('| 通过 |', report)

    def test_report_contains_no_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'report.md'
            _, report = runner.run(real=False, output=output)
            self.assertIsNone(
                re.search(r'ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}',
                          report))

    def test_cases_fixture_has_keywords(self):
        import json
        cases = json.loads(
            runner.CASES_FILE.read_text(encoding='utf8'))
        self.assertGreaterEqual(len(cases), 10)
        for case in cases:
            self.assertIn('expect_keywords', case, case['name'])
            self.assertTrue(case['expect_keywords'], case['name'])


if __name__ == '__main__':
    unittest.main()
