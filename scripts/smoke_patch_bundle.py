"""Hosted Windows real base/patch/rollback and running-app rejection proof."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
from scripts.build_patch import digest
def main():
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
        if manifest['patch_id'] in {'m145-b1','m15-b1','m15-b2','m15-b2a','m15-b4'}:
            subprocess.run([sys.executable,'scripts/smoke_windows_bundle.py',str(bundle)],check=True)
            subprocess.run([str(bundle/'backend/python/python.exe'),'-B','-X','utf8','-c',
                'from server.config import Config; from server.api.app import ThreadedWSGIServer; assert Config.env().history_rounds==10; assert ThreadedWSGIServer.daemon_threads'],cwd=bundle/'backend',check=True)
        if manifest['patch_id']=='m15-b1':
            configfile=bundle/'config/bubbles.yaml';original_config=configfile.read_bytes()
            def configured():
                subprocess.run([str(bundle/'xinghui_companion.exe'),'--bubble-config-smoke'],check=True,timeout=20)
                return json.loads((bundle/'bubble-config-smoke.json').read_text(encoding='utf8'))
            assert configured()['companionLightColor']=='#FFFFFF'
            data=json.loads(original_config);data['skins'][data['defaultSkin']]['companionLightColor']='#E5DCF6'
            configfile.write_text(json.dumps(data,ensure_ascii=False),encoding='utf8')
            assert configured()['companionLightColor']=='#E5DCF6'
            configfile.write_bytes(original_config);(bundle/'bubble-config-smoke.json').unlink()
            print('Native Windows external bubbles.yaml edit and process restart: PASS')
        if manifest['patch_id'] in {'m15-b2','m15-b2a','m15-b4'}:
            subprocess.run([sys.executable,'scripts/smoke_m15_b2.py',str(bundle)],check=True)
        if manifest['patch_id']=='m15-b4':
            subprocess.run([sys.executable,'scripts/smoke_model_wizard.py',str(bundle)],check=True)
            import winreg
            with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER,'Environment',0,winreg.KEY_QUERY_VALUE|winreg.KEY_SET_VALUE) as registry:
                try:previous_provider=winreg.QueryValueEx(registry,'ACTIVE_PROVIDER')
                except FileNotFoundError:previous_provider=None
                winreg.SetValueEx(registry,'ACTIVE_PROVIDER',0,winreg.REG_SZ,'siliconflow')
        result=apply(patch/'revert.bat' if manifest['patch_id'] in {'m15-b2','m15-b2a','m15-b4'} else bundle/'revert.bat');assert result.returncode==0,result.stdout+result.stderr
        if manifest['patch_id']=='m15-b4':
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,'Environment') as registry:
                try:restored_provider=winreg.QueryValueEx(registry,'ACTIVE_PROVIDER')
                except FileNotFoundError:restored_provider=None
                assert restored_provider==previous_provider
            print('Native model provider environment restores on independent b4 revert; keys untouched: PASS')
        assert version()==before;assert (bundle/'install-state.json').read_bytes()==state
        for relative,original in originals.items():
            target=bundle/relative
            assert digest(target)==original if original is not None else not target.exists()
        # Proof is synthetic only. Remove rehearsal backup/control files from base.
        import shutil
        shutil.rmtree(bundle/'backup'/manifest['patch_id']);(bundle/'revert.bat').unlink();(bundle/'.patch.lock').unlink();(bundle/'version-stamp-smoke.txt').unlink()
        print('Real Windows base/version/App-running rejection/apply/backup/revert: PASS')

if __name__=='__main__':
    try:main()
    except Exception:
        import traceback
        detail=traceback.format_exc().replace('%','%25').replace('\r','%0D').replace('\n','%0A')
        print('::error::'+detail,flush=True)
        sys.exit(1)
