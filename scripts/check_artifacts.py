"""Fail release if packaged output unexpectedly contains private stores or keys."""
import sys
import zipfile
from pathlib import Path
BLOCKED={'.db','.sqlite','.sqlite3','.pem','.key','.jks','.keystore'}
BLOCKED_PARTS={'runtime','exports','chat_logs','.env','.git','datasets','weights','cache','__pycache__','.venv','backup'}
def safe(name):
    p=Path(name)
    parts=[x.lower() for x in p.parts]
    user_assets=any(parts[i]=='assets' and parts[i+1] in {'voices','pet'} for i in range(len(parts)-1))
    database_journal=p.name.lower().endswith(tuple(ext+tail for ext in ('.db','.sqlite','.sqlite3') for tail in ('-wal','-shm','-journal')))
    return not (user_assets or database_journal or p.suffix.lower() in BLOCKED or any(x in BLOCKED_PARTS for x in parts))
def inspect(path):
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            bad=[n for n in z.namelist() if not safe(n)]
        if bad: raise SystemExit('禁止发布敏感文件路径：'+str(bad))
    elif not safe(str(path)): raise SystemExit('禁止发布：'+str(path))
if __name__=='__main__':
    for arg in sys.argv[1:]:
        p=Path(arg)
        if p.is_dir():
            for f in p.rglob('*'):
                if f.is_file(): inspect(f)
        else: inspect(p)
    print('artifact path scan passed; not a substitute for security review')
