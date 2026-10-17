# 模块十五批次三 a：确认链路重构与人设 v1.4 修复批

基线：codex/m15 @ f907a5d（m15-b3 0444437 + m15-b4 向导）。本批修复 b3 验收后发现的 D5–D13 缺陷，一次并入 m15-b3a 交付。

## 缺陷清单与处置

| 缺陷 | 内容 | 状态 | 根因 |
|---|---|---|---|
| D5 | 同一时段反复打开应用问候重复 | 已修 | 问候未去重；改为按 saved['greeting_slots']（当天+voice_scene）去重 |
| D6 | 回答偶发"一字不差"疑似缓存污染 | 已修 | 真凶是风格兜底固定文案而非缓存；fallback 改三条按小时轮换并过 style_hits 校验；retriever 5 分钟缓存仅作用于记忆索引，属合法保留 |
| D7 | 客户端混用"星辉/星回" | 已修 | 显示文案统一"星回"（theme.yaml appTitle、备份校验、通知显示名）；channel id/appUserModelId/GUID/文件名/bat 入口不动 |
| D8 | 每轮强制确认模型调用 | 已修 | 三层叠加：b3 0444437 会话层 + 模块一 env 层 + 客户端 confirmApi 重置。删除会话层与客户端 confirmApi，env 层由 migrate_legacy_confirmation() 一次性清理 HKCU\Environment 残留（A 方案，幂等，store 门控仅迁一次）；新链路=设置页"允许云端模型调用"持久开关，env REQUIRE_API_CONFIRMATION=false 仍可强制静默覆盖 |
| D9 | "我们的记忆有哪些"类总览问题检索为空 | 已修 | OVERVIEW_PATTERN 命中时注入最近 5 条已批准记忆，句限放宽到 5 |
| D12 | 年龄写死 23 | 已修 | compute_age(today) 以 2000-10-16 为锚实时计算并注入提示与 today_context，静态卡删除年龄条目 |
| D13 | 破角色回答（AI 自称/没有身体等） | 已修 | 人设卡 v1.4 黑名单扩容 + BREAK_PATTERN 正则 + 重试 prompt 改"以星回的身份重新回答…可正常描述吃饭睡觉等日常活动"；连续两次命中记 style_violation_alerts 供验收核对 |

## b4 向导与残留的关系（git 验证）

`git log -S REQUIRE_API_CONFIRMATION` 证实向导提交 e5fc0bf 仅在环境变量白名单与 smoke 夹具中保留该名字，从未向用户 HKCU\Environment 写入；实际写入者是 b3 模块一的 env 层。因此清理目标仅注册表/环境块残留，与向导回滚逻辑无冲突。

## 自测结果

- 后端：`python -X utf8 -m unittest discover -s tests`（工作副本 sys.path 前插）134 个测试全绿，含新增 tests/test_m15_b3a.py（compute_age 五组日期边界、问候同时段三次仅一条/次日新时段再发、破角色正则、句限放宽、fallback 轮换不破角色、总览注入记忆、连续命中记告警）。
- 注意：用底座自带 python 跑测试时其 app-home 会把旧版 backend 压进 sys.path 遮蔽工作副本，必须显式前插仓库根目录，否则测到旧代码出现假失败。
- Flutter：本机未装 Flutter 工具链，flutter analyze/test 留给 GitHub Actions；chat_flow_test.dart 已改写为持久开关语义（PATCH /settings cloud_api_allowed，/chat 请求体不再含 api_confirmed）。
- 真实 GLM 轮次未执行（工作区无 Key、不以 mock 冒充），留用户用 scripts/probe_persona_regression.py --approve-test-api 实测。

## 人设门禁

docs/persona/persona_eval_report.md 已更新至 v1.4：结构门禁全过，核心 SHA256 337e373ebe60eb75b65aaa22574b33f88223dc362fd8926116ba3e6aae021d63，客户端离线镜像与 config 版字节一致。

## 改动文件

后端：config/persona_v1_4.json、server/persona/core.py、server/api/app.py、server/companion.py、server/model_environment.py、server/providers/mock.py、server/config.py、server/model_service.py、scripts/local_backend.py、scripts/probe_persona_regression.py、scripts/rollback_persona.py、scripts/smoke_model_wizard.py、scripts/smoke_persona_bundle.py
客户端：client/flutter_app/lib/main.dart、persona_assets.dart、personal_backup.dart、reminder_service.dart、assets/theme.yaml、assets/persona/persona_v1_4.json、test/chat_flow_test.dart
测试：tests/test_m15_b3a.py（新增）、test_api.py、test_chat_context.py、test_companion_v1.py 等同步更新
文档：docs/persona/persona_eval_report.md、docs/module-15-b3a-acceptance.md

不变项：TTS、exe 名、bat 脚本入口、通知 channel id/GUID、免费模型零确认、收费模型 ALLOW_PAID_API 首次向导确认。
