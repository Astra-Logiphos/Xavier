import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from scripts.build_patch import demo, package, backend_patch
from scripts.check_artifacts import safe

class PatchPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.base=self.root/'base';self.base.mkdir();
        (self.base/'install-state.json').write_text(json.dumps({'schema':1,'base_git_hash':'abcdef0','patch_id':None}))
        (self.base/'docs').mkdir();(self.base/'docs/windows-preview.md').write_text('original')
    def test_demo_only_replaces_existing_doc_and_is_small(self):
        output=self.root/'out';manifest=demo(self.base,'abcdef012345',output)
        self.assertEqual(manifest['source_changes'],['docs/windows-preview.md']);self.assertEqual(manifest['file_count'],1)
        self.assertEqual(manifest['files'][0]['path'],'docs/windows-preview.md')
        with zipfile.ZipFile(output/'m145-b0-patch.zip') as z:
            self.assertEqual([n for n in z.namelist() if n.startswith('payload/')],['payload/docs/windows-preview.md'])
        self.assertLess((output/'m145-b0-patch.zip').stat().st_size,1024*1024)
        self.assertEqual([p.name for p in output.iterdir()],['m145-b0-patch.zip'])
    def test_identical_dll_excluded_changed_file_included(self):
        candidate=self.root/'candidate';candidate.mkdir();(self.base/'runtime.dll').write_bytes(b'same');(candidate/'runtime.dll').write_bytes(b'same');(candidate/'changed.py').write_text('changed')
        manifest=package(self.base,candidate,self.root/'patch.zip','abcdef0',['server/changed.py'])
        self.assertEqual([r['path'] for r in manifest['files']],['changed.py'])
    def test_user_content_never_accepted(self):
        for path in ['assets/voices/a.wav','assets/pet/x/idle.png','backup/b0/a','backend/memory.db','nested/memory.sqlite3','memory.db-wal','assets/Voices/a.wav']:
            self.assertFalse(safe(path),path)
        candidate=self.root/'candidate';(candidate/'assets/voices').mkdir(parents=True);(candidate/'assets/voices/a.wav').write_bytes(b'user')
        with self.assertRaises(ValueError):package(self.base,candidate,self.root/'bad.zip','abcdef0',[])

    def test_backend_mapping_uses_git_diff_and_excludes_runtime(self):
        from unittest.mock import patch
        (self.base/'install-state.json').write_text(json.dumps({'schema':1,'base_git_hash':'666e2e2','patch_id':None}))
        changes=['server/model_config.py','config/chat.json','tests/test_model_config.py','scripts/build_patch.py']
        with patch('scripts.build_patch.source_changes',return_value=changes) as diff:
            manifest=backend_patch(self.base,'abcdef0',self.root/'out')
        diff.assert_called_once_with('666e2e2','abcdef0')
        self.assertEqual([r['path'] for r in manifest['files']],['backend/config/chat.json','backend/server/model_config.py'])
        self.assertEqual(manifest['previous_patch'],None)
        self.assertLess((self.root/'out/m145-b1-patch.zip').stat().st_size,1024*1024)
    def test_backend_mapping_rejects_frontend_and_wrong_chain(self):
        from unittest.mock import patch
        (self.base/'install-state.json').write_text(json.dumps({'schema':1,'base_git_hash':'666e2e2','patch_id':None}))
        with patch('scripts.build_patch.source_changes',return_value=['client/flutter_app/lib/main.dart']):
            with self.assertRaises(ValueError):backend_patch(self.base,'abcdef0',self.root/'out')
        (self.base/'install-state.json').write_text(json.dumps({'schema':1,'base_git_hash':'666e2e2','patch_id':'m145-b0'}))
        with self.assertRaises(ValueError):backend_patch(self.base,'abcdef0',self.root/'out')
