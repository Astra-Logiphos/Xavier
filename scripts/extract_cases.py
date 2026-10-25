"""从指定 jsonl 会话文件抽取人设回归用例草稿。

用法：python scripts/extract_cases.py <chat.jsonl> [-o cases_draft.md]
- 只读显式传入的一个路径，禁止扫盘。
- 每行一个 JSON；宽容识别常见字段（role/type + content/message/text）。
- 输出 Markdown：每对 用户原话→助手实际回答 一节，expect 留空待人工补。
- 不写任何 Key；不修改源文件。
"""
import argparse
import json
from pathlib import Path


def _text(payload):
    if isinstance(payload, str):
        return payload
    if isinstance(payload, dict):
        for key in ('content', 'message', 'text'):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value
    return ''


def parse_entries(lines):
    entries = []
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        role = row.get('role') or row.get('type') or row.get('author')
        if not isinstance(role, str):
            continue
        text = _text(row.get('content')) or _text(row)
        if role.lower() in {'user', 'human', '用户'} and text:
            entries.append(('user', text))
        elif role.lower() in {'assistant', 'ai', 'model', '星回'} and text:
            entries.append(('assistant', text))
    return entries


def build_draft(entries):
    pairs, pending = [], None
    for role, text in entries:
        if role == 'user':
            pending = text
        elif role == 'assistant' and pending is not None:
            pairs.append((pending, text))
            pending = None
    lines = ['# 人设回归用例草稿', '',
             '从会话记录自动抽取；expect 由人工补齐后再交给 merge_cases.py。', '']
    for index, (question, answer) in enumerate(pairs, 1):
        lines += [f'## 用例 {index}', '',
                  f'- input: {question}', f'- actual: {answer}',
                  '- expect_keywords: （待人工补）', '- expected_policy: （待人工补）', '']
    lines += [f'共抽取 {len(pairs)} 对对话。', '']
    return '\n'.join(lines), len(pairs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('jsonl', help='会话 jsonl 文件路径（只读这一个文件）')
    parser.add_argument('-o', '--output', default='cases_draft.md')
    args = parser.parse_args()
    source = Path(args.jsonl)
    if not source.is_file():
        raise SystemExit(f'文件不存在：{source}（本工具不扫描目录）')
    draft, count = build_draft(parse_entries(source.read_text(encoding='utf8', errors='replace').splitlines()))
    Path(args.output).write_text(draft, encoding='utf8')
    print(f'抽取 {count} 对 → {args.output}')


if __name__ == '__main__':
    main()
