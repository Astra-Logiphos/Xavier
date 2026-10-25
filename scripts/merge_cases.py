"""合并已补齐 expect 的新用例到 data/sample/persona_eval_cases.json。

用法：python scripts/merge_cases.py <filled_cases.json> [--real]
- filled_cases.json：extract_cases.py 产物经人工补 expect 后的结构化版
  [{input, expect_keywords, expected_policy}, ...]
- 旧用例一个字不动（追加到数组末尾）。
- 新用例逐条跑评估（--real 走真实模型，缺省静态护栏）：
  全过且零风格回退 → 追加写入 + 生成 v1.5 人设升级建议文件（不自动 active）；
  任一失败 → 输出冲突报告，不改动 cases.json。
"""
import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from server.persona_eval import runner  # noqa: E402

# 路径作模块常量，测试可整体替换到临时目录，绝不触碰真实文件。
CASES = ROOT / 'data/sample/persona_eval_cases.json'
PROPOSAL = ROOT / 'docs/persona/persona_v1_5_proposal.md'
CONFLICT_REPORT = ROOT / 'runtime/merge_conflicts.md'
EVAL_REPORT = ROOT / 'runtime/merge_eval_report.md'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('filled', help='已补齐 expect 的新用例 JSON 文件')
    parser.add_argument('--real', action='store_true', help='用真实模型逐条评估')
    args = parser.parse_args()
    new_cases = json.loads(Path(args.filled).read_text(encoding='utf8'))
    if not isinstance(new_cases, list) or not new_cases:
        raise SystemExit('新用例文件必须是非空数组')
    for case in new_cases:
        if not case.get('input') or not case.get('expect_keywords'):
            raise SystemExit('每条用例都需要 input 与非空 expect_keywords')

    summary, report = runner.run(real=True if args.real else False,
                                 output=EVAL_REPORT, cases=new_cases)
    ok = summary['passed'] == summary['total'] and summary['mode'] == 'real'
    regressions = [line for line in report.splitlines() if '风格命中' in line]
    if not ok or regressions:
        CONFLICT_REPORT.write_text(
            '# 新用例冲突报告\n\n'
            f'- 评估模式：{summary["mode"]}（--real 才允许合入）\n'
            f'- 通过：{summary["passed"]}/{summary["total"]}\n'
            f'- 风格回退条数：{len(regressions)}\n\n'
            '未改动 cases.json。逐条明细：\n\n' + report, encoding='utf8')
        print(f'存在失败或回退 → 冲突报告 {CONFLICT_REPORT}；cases.json 未改动')
        return 1

    existing = json.loads(CASES.read_text(encoding='utf8'))
    next_id = max(case['id'] for case in existing) + 1
    appended = [dict(case, id=next_id + offset)
                for offset, case in enumerate(new_cases)]
    backup = CASES.with_suffix('.json.bak')
    shutil.copy2(CASES, backup)
    CASES.write_text(json.dumps(existing + appended, ensure_ascii=False, indent=2) + '\n',
                     encoding='utf8')
    stamp = datetime.now(timezone.utc).isoformat()
    PROPOSAL.write_text(
        '# PersonaVersion v1.5 建议（未生效）\n\n'
        f'- 生成时间：{stamp}\n- 新增用例：{len(appended)} 条（id {next_id}..{next_id + len(appended) - 1}）\n'
        '- 评估：真实模型逐条通过、零风格回退\n'
        '- 建议：由用户审核后按门禁流程发布 v1.5 人设卡；本脚本不自动 active，不修改人设状态。\n',
        encoding='utf8')
    print(f'合并 {len(appended)} 条（旧用例未动，备份 {backup.name}）→ v1.5 建议 {PROPOSAL}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
