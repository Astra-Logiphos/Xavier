from pathlib import Path
import re
import sys
repo=sys.argv[1] if len(sys.argv)>1 else ''
if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',repo): raise SystemExit('usage: python scripts/configure_repo.py OWNER/REPO')
p=Path(__file__).resolve().parents[1]/'README.md'
p.write_text(p.read_text().replace('https://github.com/OWNER/REPO/releases/latest',f'https://github.com/{repo}/releases/latest'),encoding='utf-8')
print('README download button updated; no release created')
