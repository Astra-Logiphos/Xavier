import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from scripts.build_patch import demo, digest
ROOT=Path(__file__).resolve().parents[1]

@unittest.skipUnless(os.name=='nt','Windows BAT/PowerShell integration')
class PatchApplyTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.base=self.root/'底座 with spaces';self.base.mkdir()
        shutil.copytree(ROOT/'tools/pack',self.base/'tools/pack')
        self.state={'schema':1,'module':'m145','batch':'base','git_hash':'abcdef0','base_git_hash':'abcdef0','patch_id':None}
        (self.base/'install-state.json').write_text(json.dumps(self.state));(self.base/'docs').mkdir();(self.base/'docs/windows-preview.md').write_text('original',encoding='utf8')
        output=self.root/'out';demo(self.base,'abcdef0123',output);self.patch=self.root/'补丁';zipfile.ZipFile(output/'m145-b0-patch.zip').extractall(self.patch)
    def run_bat(self,script):
        env=dict(os.environ,XINGHUI_INSTALL_ROOT=str(self.base),XINGHUI_PATCH_TEST='1')
        return subprocess.run([os.environ.get('COMSPEC','cmd.exe'),'/d','/c',str(script)],env=env,capture_output=True,encoding='utf8',errors='replace',timeout=30)
    def test_workflow_predecessor_launcher_applies_patch_and_preserves_errors(self):
        workflow=(ROOT/'.github/workflows/build-windows.yml').read_text(encoding='utf8')
        commands=[line.strip() for line in workflow.splitlines() if line.strip().startswith('cmd.exe /d /c ')]
        self.assertEqual(len(commands),1)
        shutil.copytree(self.patch,self.root/'previous-patch')
        env=dict(os.environ,XINGHUI_INSTALL_ROOT=str(self.base),XINGHUI_PATCH_TEST='1')
        def launch():
            return subprocess.run(['pwsh','-NoProfile','-NonInteractive','-Command',commands[0]+'; exit $LASTEXITCODE'],
                                  cwd=self.root,env=env,capture_output=True,encoding='utf8',errors='replace',timeout=30)
        result=launch()
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(json.loads((self.base/'install-state.json').read_text())['patch_id'],'m145-b0')
        result=launch()
        self.assertNotEqual(result.returncode,0,'Repeated patch application must propagate failure')
    def test_apply_backup_revert(self):
        old=(self.base/'install-state.json').read_bytes();before=digest(self.base/'docs/windows-preview.md')
        result=self.run_bat(self.patch/'apply_patch.bat');self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(json.loads((self.base/'install-state.json').read_text(encoding='utf-8-sig'))['patch_id'],'m145-b0')
        self.assertEqual(digest(self.base/'backup/m145-b0/files/docs/windows-preview.md'),before)
        result=self.run_bat(self.base/'revert.bat');self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(digest(self.base/'docs/windows-preview.md'),before);self.assertEqual((self.base/'install-state.json').read_bytes(),old)
    def test_tampered_payload_rejected_without_changes(self):
        (self.patch/'payload/docs/windows-preview.md').write_text('tampered');result=self.run_bat(self.patch/'apply_patch.bat');self.assertNotEqual(result.returncode,0);self.assertEqual((self.base/'docs/windows-preview.md').read_text(),'original')
    def test_wrong_base_and_path_traversal_rejected(self):
        file=self.patch/'manifest.json';data=json.loads(file.read_text());data['base_git_hash']='wrong';file.write_text(json.dumps(data));self.assertNotEqual(self.run_bat(self.patch/'apply_patch.bat').returncode,0)
        data['base_git_hash']='abcdef0';data['files'][0]['path']='../outside';file.write_text(json.dumps(data));self.assertNotEqual(self.run_bat(self.patch/'apply_patch.bat').returncode,0)
    def test_repeated_apply_and_extra_file_rejected(self):
        extra=self.patch/'payload/extra.txt';extra.write_text('unexpected')
        self.assertNotEqual(self.run_bat(self.patch/'apply_patch.bat').returncode,0)
        self.assertEqual((self.base/'docs/windows-preview.md').read_text(),'original')
        extra.unlink()
        self.assertEqual(self.run_bat(self.patch/'apply_patch.bat').returncode,0);self.assertNotEqual(self.run_bat(self.patch/'apply_patch.bat').returncode,0)
