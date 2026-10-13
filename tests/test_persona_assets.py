import unittest
from server.persona.assets import load_persona, render_prompt

class PersonaAssetTests(unittest.TestCase):
    def test_report_and_template_available_without_model(self):
        data=load_persona()
        self.assertEqual(len(data['情绪场景表']),9)
        self.assertEqual(data['version'],'xavier-report-1')
        prompt=render_prompt([], 'learning')
        self.assertIn('沈星回',prompt)
        self.assertIn('专业事实保持准确',prompt)
        self.assertIn('尊重删除与不记录',prompt)
        self.assertNotIn('{{',prompt)
    def test_unapproved_memories_are_excluded(self):
        rows=[{'content':'已确认内容','consent':True,'review_status':'approved','confidence':1},
              {'content':'尚未批准内容','consent':True,'review_status':'pending_review','confidence':1},
              {'content':'无同意内容','consent':False,'review_status':'approved','confidence':1}]
        prompt=render_prompt(rows)
        self.assertIn('已确认内容',prompt)
        self.assertNotIn('尚未批准内容',prompt)
        self.assertNotIn('无同意内容',prompt)
