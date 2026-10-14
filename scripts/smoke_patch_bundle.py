"""Hosted Windows real base/patch/rollback and running-app rejection proof."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
from scripts.build_patch import digest
bundle=Path(sys.argv[1]).resolve();patchzip=Path(sys.argv[2]).resolve()
with tempfile.TemporaryDirectory() as temporary:
    patch=Path(temporary)/'patch';zipfile.ZipFile(patchzip).extractall(patch)
    env=dict(os.environ,XINGHUI_INSTALL_ROOT=str(bundle),XINGHUI_PATCH_TEST='1')
    def apply(script):return subprocess.run([os.environ['COMSPEC'],'/d','/c',str(script)],env=env,capture_output=True,encoding='utf8',errors='replace',timeout=40)
    def version():
        result=subprocess.run([str(bundle/'xinghui_companion.exe'),'--version-stamp-smoke'],timeout=20);assert result.returncode==0
        return (bundle/'version-stamp-smoke.txt').read_text(encoding='utf8')
    manifest=json.loads((patch/'manifest.json').read_text(encoding='utf8'))
    before=version();state=(bundle/'install-state.json').read_bytes()
    originals={entry['path']:digest(bundle/entry['path']) if (bundle/entry['path']).exists() else None for entry in manifest['files']}
    app=subprocess.Popen([str(bundle/'xinghui_companion.exe')])
    try:
        result=apply(patch/'apply_patch.bat');assert result.returncode!=0 and 'App' in result.stdout,result.stdout+result.stderr
    finally:app.terminate();app.wait(timeout=15)
    result=apply(patch/'apply_patch.bat');assert result.returncode==0,result.stdout+result.stderr
    after=version();assert after.startswith(manifest['patch_id'])
    for entry in manifest['files']:
        assert digest(bundle/entry['path'])==entry['sha256']
    if manifest['patch_id']=='m145-b1':
        subprocess.run([sys.executable,'scripts/smoke_windows_bundle.py',str(bundle)],check=True)
        subprocess.run([str(bundle/'backend/python/python.exe'),'-B','-X','utf8','-c',
            'from server.config import Config; from server.api.app import ThreadedWSGIServer; assert Config.env().history_rounds==10; assert ThreadedWSGIServer.daemon_threads'],cwd=bundle/'backend',check=True)
    result=apply(bundle/'revert.bat');assert result.returncode==0,result.stdout+result.stderr
    assert version()==before;assert (bundle/'install-state.json').read_bytes()==state
    for relative,original in originals.items():
        target=bundle/relative
        assert digest(target)==original if original is not None else not target.exists()
    # Proof is synthetic only. Remove rehearsal backup/control files from base.
    import shutil
    shutil.rmtree(bundle/'backup');(bundle/'revert.bat').unlink();(bundle/'.patch.lock').unlink();(bundle/'version-stamp-smoke.txt').unlink()
    print('Real Windows base/version/App-running rejection/apply/backup/revert: PASS')
