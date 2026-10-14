"""Reproducible base state and incremental packages; Python standard library only."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile
from scripts.check_artifacts import safe

ROOT=Path(__file__).resolve().parents[1]
DEMO='docs/windows-preview.md'

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def dump(path,value):Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def source_changes(before,after):
    return subprocess.check_output(['git','diff','--name-only',before,after],cwd=ROOT,text=True).splitlines()
def initialize(bundle,revision):
    bundle=Path(bundle)
    short=revision[:7]
    dump(bundle/'install-state.json',{'schema':1,'module':'m145','batch':'base','git_hash':short,'base_git_hash':short,'patch_id':None})
    shutil.copytree(ROOT/'tools/pack',bundle/'tools/pack',dirs_exist_ok=True)
    (bundle/'docs').mkdir(exist_ok=True)
    shutil.copy2(ROOT/DEMO,bundle/DEMO)
    shutil.copy2(ROOT/'docs/module-145-b0-acceptance.md',bundle/'docs/module-145-b0-acceptance.md')

def package(base,candidate,output,revision,changes,patch_id='m145-b0'):
    base,candidate,output=Path(base),Path(candidate),Path(output)
    state=json.loads((base/'install-state.json').read_text(encoding='utf-8-sig'))
    selected=[]
    for path in sorted(candidate.rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(candidate).as_posix()
        if not safe(relative):raise ValueError('禁止打包用户资产：'+relative)
        previous=base/relative
        if previous.exists() and digest(previous)==digest(path):continue
        selected.append((relative,path,previous))
    if not selected:raise ValueError('补丁没有变化')
    entries=[{'path':r,'size':p.stat().st_size,'sha256':digest(p),'before_sha256':digest(old) if old.exists() else None} for r,p,old in selected]
    manifest={'schema':1,'module':'m145','batch':patch_id.split('-')[1],'patch_id':patch_id,'git_hash':revision[:7],'base_git_hash':state['base_git_hash'],'previous_patch':state['patch_id'],'source_changes':changes,'file_count':len(entries),'files':entries}
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        for relative,path,_ in selected:z.write(path,'payload/'+relative)
        for path in (ROOT/'tools/pack').iterdir():
            if path.is_file():z.write(path,'tools/pack/'+path.name)
        z.write(ROOT/'tools/pack/apply_patch.bat','apply_patch.bat')
    return manifest

def demo(bundle,revision,output):
    output=Path(output);candidate=output/'demo-candidate';candidate.mkdir(parents=True,exist_ok=True)
    # A disposable Git index makes the existing-document replacement an actual
    # git diff --name-only, without committing demo text into the project guide.
    source=output/'demo-source';source.mkdir(parents=True,exist_ok=True)
    subprocess.run(['git','init','-q',str(source)],check=True)
    document=source/DEMO;document.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(Path(bundle)/DEMO,document)
    subprocess.run(['git','add',DEMO],cwd=source,check=True)
    document.write_text('# 模块14.5补丁演练\n\n此文件已被 m145-b0 演示补丁替换。回退后恢复原文；主题与背景完全未修改。\n',encoding='utf-8')
    changes=subprocess.check_output(['git','diff','--name-only'],cwd=source,text=True).splitlines()
    assert changes==[DEMO]
    target=candidate/DEMO;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(document,target)
    manifest=package(bundle,candidate,output/'m145-b0-patch.zip',revision,changes)
    assert (output/'m145-b0-patch.zip').stat().st_size<1024*1024
    shutil.rmtree(candidate)
    # Git objects are read-only on Windows; this is our disposable demo index.
    for path in source.rglob('*'):
        if path.is_file():path.chmod(0o600)
    shutil.rmtree(source)
    return manifest

def backend_patch(bundle, revision, output):
    """Map the real git diff to installed files, excluding unchanged runtimes."""
    bundle, output = Path(bundle), Path(output)
    state = json.loads((bundle/'install-state.json').read_text(encoding='utf-8-sig'))
    if state['base_git_hash'] != '666e2e2' or state['patch_id'] is not None:
        raise ValueError('本批入口要求 666e2e2 纯净底座（b0 已回退）')
    changes = source_changes(state['base_git_hash'], revision)
    with __import__('tempfile').TemporaryDirectory() as temporary:
        candidate = Path(temporary)
        for name in changes:
            if name.startswith(('server/', 'config/')) or name == '.env.example':
                relative = 'backend/' + name
            elif name == 'docs/module-145-b1-acceptance.md':
                relative = name
            else:
                # Tests, CI and build scripts are source verification tooling,
                # not installed backend code. Frontend changes need another mode.
                if name.startswith('client/'):
                    raise ValueError('纯后端补丁禁止遗漏前端变化：'+name)
                continue
            source = ROOT/name
            if not source.is_file():
                raise ValueError('本批不支持静默删除安装文件：'+name)
            target = candidate/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        return package(bundle, candidate, output/'m145-b1-patch.zip', revision, changes, 'm145-b1')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('bundle');parser.add_argument('revision');parser.add_argument('output');parser.add_argument('--backend',action='store_true');args=parser.parse_args()
    if args.backend:
        manifest=backend_patch(args.bundle,args.revision,args.output)
        print(json.dumps({'file_count':manifest['file_count'],'size':(Path(args.output)/'m145-b1-patch.zip').stat().st_size}))
    else:
        initialize(args.bundle,args.revision)
        demo(args.bundle,args.revision,args.output)
