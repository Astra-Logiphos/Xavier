"""人设评估 runner：加载 data/sample/persona_eval_cases.json 逐例检查。

Provider 可用（本机环境已配置 Key 且启用）时发送真实聊天轮，按
expect_keywords 做包含检查，并用 style_hits 复核回复合规；Provider 不可用
时退化为静态检查（活跃提示中安全护栏齐全 + 关键词策略标注在案）。
输出 Markdown 报告（默认 runtime/persona_eval_report.md）。
任何路径都不读取、不写出 API Key。
"""
import argparse
import json
from dataclasses import replace
from pathlib import Path

from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.model_config import read_model_config
from server.persona.core import style_hits

ROOT = Path(__file__).resolve().parents[2]
CASES_FILE = ROOT / 'data/sample/persona_eval_cases.json'
GUARDS = ('不声称自己是真人', '专业事实保持准确', '尊重删除与不记录')


def _provider_ready():
    try:
        return read_model_config('zhipu')
    except ValueError:
        return None


def run(real=None, output=ROOT / 'runtime/persona_eval_report.md', cases=None):
    """real=None 自动探测；cases 可注入用例列表（默认读 CASES_FILE）。"""
    if cases is None:
        cases = json.loads(CASES_FILE.read_text(encoding='utf8'))
    if real is None:
        real = _provider_ready() is not None
    app = Application(Config(database=':memory:', token='fixture'),
                      Store(':memory:'))
    prompt = app.persona.current()['snapshot']['prompt']
    static_guards_ok = all(guard in prompt for guard in GUARDS)
    rows = []
    for case in cases:
        if real:
            app.store.set_setting('cloud_api_allowed', True)
            response = app.chat({'text': case['input'], 'no_save': True})
            reply = response['reply']
            hit = any(k in reply for k in case['expect_keywords'])
            clean = not style_hits(reply)
            passed = hit and clean
            rows.append(dict(case, mode='real', reply=reply,
                             keyword_hit=hit, style_clean=clean, passed=passed))
        else:
            rows.append(dict(case, mode='static', reply='',
                             keyword_hit=None, style_clean=None,
                             passed=static_guards_ok))
    app.store.db.close()
    summary = dict(total=len(rows),
                   mode='real' if real else 'static',
                   passed=sum(1 for r in rows if r['passed']),
                   static_guards_ok=static_guards_ok,
                   provider=getattr(_provider_ready(), 'model', None)
                   if real else None)
    lines = ['# persona_eval_report（runner 生成）', '',
             f"- 模式：{summary['mode']}"
             + (f"（provider={summary['provider']}）" if real else '（未配置 Key，静态检查）'),
             f"- 护栏齐全（真实人/事实/隐私）：{static_guards_ok}",
             f"- 通过：{summary['passed']}/{summary['total']}", '',
             '| # | 场景 | 模式 | 结果 | 备注 |', '|---|---|---|---|---|']
    for r in rows:
        note = r.get('expected_policy', '')
        if r['mode'] == 'real':
            if not r['keyword_hit']:
                note += '；关键词未命中'
            if not r['style_clean']:
                note += '；风格命中'
            note += '；回复：' + r['reply'][:40]
        label = r.get('name') or r.get('input', '')[:12]
        lines.append(f"| {r.get('id', '-')} | {label} | {r['mode']} |"
                     f" {'通过' if r['passed'] else '失败'} | {note} |")
    report = '\n'.join(lines) + '\n'
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report, encoding='utf8')
    return summary, report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default=str(ROOT / 'runtime/persona_eval_report.md'))
    parser.add_argument('--static', action='store_true', help='强制静态检查，不调用模型')
    args = parser.parse_args()
    summary, _ = run(real=False if args.static else None, output=args.output)
    print(json.dumps(summary, ensure_ascii=False))
    return 0 if summary['passed'] == summary['total'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
