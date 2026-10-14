import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from scripts.build_patch import frontend_patch
class FrontendPatchTests(unittest.TestCase):
    def test_predecessor_module_and_runtime_exclusion(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);base=root/'base';candidate=root/'candidate'
            for item in [base,candidate]:
                (item/'backend/python').mkdir(parents=True);(item/'backend/python/python.exe').write_bytes(b'unchanged')
                (item/'data').mkdir();(item/'runtime.dll').write_bytes(b'unchanged')
            (base/'install-state.json').write_text(json.dumps({'schema':1,'base_git_hash':'666e2e2','patch_id':'m145-b1','git_hash':'b2a570f'}))
            (base/'data/app.so').write_bytes(b'old');(candidate/'data/app.so').write_bytes(b'new')
            (candidate/'backend/python/python.exe').write_bytes(b'rebuilt but unused')
            with patch('scripts.build_patch.source_changes',return_value=['client/flutter_app/lib/chat_page.dart']) as diff:
                manifest=frontend_patch(base,candidate,'abcdef0',root/'out')
            diff.assert_called_once_with('b2a570f','abcdef0')
            self.assertEqual(manifest['module'],'m15');self.assertEqual(manifest['previous_patch'],'m145-b1')
            self.assertEqual([x['path'] for x in manifest['files']],['data/app.so'])
    def test_wrong_predecessor_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);(base/'install-state.json').write_text(json.dumps({'base_git_hash':'666e2e2','patch_id':None,'git_hash':'666e2e2'}))
            with self.assertRaises(ValueError):frontend_patch(base,base,'abcdef0',base/'out')

    def test_batch_two_predecessor_and_standalone_revert(self):
        import zipfile
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);base=root/'base';candidate=root/'candidate'
            for item in [base,candidate]:
                (item/'backend/python').mkdir(parents=True);(item/'backend/python/python.exe').write_bytes(b'same')
            (base/'install-state.json').write_text(json.dumps({'base_git_hash':'666e2e2','patch_id':'m15-b1','git_hash':'1757908'}))
            (candidate/'start_all.bat').write_bytes(b'new launcher')
            with patch('scripts.build_patch.source_changes',return_value=['start_all.bat']):
                manifest=frontend_patch(base,candidate,'abcdef0',root/'out','m15-b2')
            self.assertEqual(manifest['previous_patch'],'m15-b1')
            with zipfile.ZipFile(root/'out/m15-b2-patch.zip') as archive:
                self.assertIn('revert.bat',archive.namelist())
                self.assertIn(b'XINGHUI_REVERT_PATCH_ID=m15-b2',archive.read('revert.bat'))
    def test_user_avatars_never_packaged(self):
        from scripts.check_artifacts import safe
        self.assertFalse(safe('payload/config/avatars/avatar-1.jpg'))
        self.assertTrue(safe('config/bubbles.yaml'))

    def test_avatar_supplement_predecessor_and_revert(self):
        import zipfile
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);base=root/'base';candidate=root/'candidate'
            for item in (base,candidate):
                (item/'backend/python').mkdir(parents=True)
                (item/'backend/python/python.exe').write_bytes(b'same')
            (base/'install-state.json').write_text(json.dumps({'base_git_hash':'666e2e2','patch_id':'m15-b2','git_hash':'22a473d'}))
            (candidate/'data').mkdir();(candidate/'data/app.so').write_bytes(b'new')
            with patch('scripts.build_patch.source_changes',return_value=['client/flutter_app/lib/avatar_store.dart']):
                manifest=frontend_patch(base,candidate,'abcdef0',root/'out','m15-b2a')
            self.assertEqual(manifest['previous_patch'],'m15-b2')
            with zipfile.ZipFile(root/'out/m15-b2a-patch.zip') as archive:
                self.assertIn(b'XINGHUI_REVERT_PATCH_ID=m15-b2a',archive.read('revert.bat'))
