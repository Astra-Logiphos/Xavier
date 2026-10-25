"""发布资产白名单扫描：仅允许 APK/zip/txt；发现隐私/凭据字样直接失败。

用法：python scripts/check_release_assets.py <目录或文件...>
规则（任务书阶段1.3）：
- 扩展名白名单：.apk / .zip / .txt（其余一律失败）
- 文件名/zip 内路径禁止：.env、*.db、*.sqlite*、*.jsonl、聊天记录、ghp_、github_pat_、sk- 字样
- 文本内容与 zip 内小文件内容扫描凭据模式（ghp_ / github_pat_ / sk-）
"""
import re
import sys
import zipfile
from pathlib import Path

ALLOWED = {'.apk', '.zip', '.txt'}
FORBIDDEN_NAME = re.compile(r'\.env($|\.)|\.db($|-)|\.sqlite|\.jsonl|聊天记录|ghp_[A-Za-z0-9]|github_pat_|sk-[A-Za-z0-9]{16}')
CREDENTIAL = re.compile(rb'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{24}')


def fail(reason):
    raise SystemExit('发布资产检查失败：' + reason)


def scan_bytes(name, data):
    if CREDENTIAL.search(data):
        fail(f'{name} 内容含凭据模式（ghp_/github_pat_/sk-）')


def inspect(path):
    suffix = path.suffix.lower()
    if suffix not in ALLOWED:
        fail(f'{path.name} 扩展名不在白名单 {sorted(ALLOWED)}')
    if FORBIDDEN_NAME.search(path.name):
        fail(f'{path.name} 文件名命中禁止模式')
    data = path.read_bytes()
    if suffix == '.zip':
        try:
            archive = zipfile.ZipFile(path)
        except zipfile.BadZipFile:
            fail(f'{path.name} 不是有效的 zip 文件')
        with archive:
            for entry in archive.namelist():
                if FORBIDDEN_NAME.search(entry):
                    fail(f'{path.name} 内含禁止路径：{entry}')
                info = archive.getinfo(entry)
                if info.is_dir():
                    continue
                if Path(entry).suffix.lower() in {'.env', '.db', '.sqlite', '.sqlite3', '.jsonl'}:
                    fail(f'{path.name} 内含禁止扩展名：{entry}')
                if info.file_size <= 2 * 1024 * 1024:
                    scan_bytes(f'{path.name}::{entry}', archive.read(entry))
    elif suffix == '.txt':
        scan_bytes(path.name, data)
    else:  # apk：只做字节级凭据扫描
        scan_bytes(path.name, data)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        fail('未提供待检目录')
    count = 0
    for arg in sys.argv[1:]:
        target = Path(arg)
        files = target.rglob('*') if target.is_dir() else [target]
        for item in files:
            if item.is_file():
                inspect(item)
                count += 1
    print(f'release asset whitelist scan passed: {count} files')
