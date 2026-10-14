import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from scripts.build_patch import demo, package
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
    def test_identical_dll_excluded_changed_file_included(self):
        candidate=self.root/'candidate';candidate.mkdir();(self.base/'runtime.dll').write_bytes(b'same');(candidate/'runtime.dll').write_bytes(b'same');(candidate/'changed.py').write_text('changed')
        manifest=package(self.base,candidate,self.root/'patch.zip','abcdef0',['server/changed.py'])
        self.assertEqual([r['path'] for r in manifest['files']],['changed.py'])
    def test_user_content_never_accepted(self):
        for path in ['assets/voices/a.wav','assets/pet/x/idle.png','backup/b0/a','backend/memory.db','nested/memory.sqlite3']:
            self.assertFalse(safe(path),path)
        candidate=self.root/'candidate';(candidate/'assets/voices').mkdir(parents=True);(candidate/'assets/voices/a.wav').write_bytes(b'user')
        with self.assertRaises(ValueError):package(self.base,candidate,self.root/'bad.zip','abcdef0',[])
