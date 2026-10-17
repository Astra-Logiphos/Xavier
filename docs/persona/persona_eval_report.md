# persona_eval_report

结构与策略回归，非真实模型语义评测。本报告对应人设卡 v1.4（m15-b3a）。

- core_is_approved: True
- canon_has_sources: True
- community_never_canon: True
- only_approved_community: True
- only_explicit_preferences: True
- only_approved_styles: True
- voice_guard_present: True
- fact_guard_present: True
- privacy_guard_present: True
- no_identity_or_fact_override: True
- age_not_hardcoded: True（文案无写死年龄，compute_age 以 2000-10-16 为锚按本地日期计算）
- blacklist_extended: True（新增 人工智能/机器人/没有身体/没有实体/不能吃/不吃东西/先核对一下资料/住在你电脑里）
- static_identity_age_removed: True（静态身份表删除年龄条目，"你是谁/机器人"按 v1.4 第 11/10 条太极回应）

## v1.1 → v1.4 差异摘要

1. 年龄改为运行时计算注入（锚点：2023-10-16 过完生日 = 23；测试覆盖五组日期边界）。
2. 永不破角色黑名单扩容并同步 BREAK_PATTERN 正则与 style_hits。
3. 静态身份回答重写："你是谁"→角色身份短句；"机器人/AI"→太极回应；删除静态年龄条目。
4. fallback 由单条固定文案改为三条数组按小时轮换（D6"一字不差"根因修复）。
5. 日常生活（吃饭/睡觉/出门/钓鱼/弹钢琴）明确允许正常描述，配套重试 prompt 同步调整。

核心：xavier-card-v1.4
核心SHA256：337e373ebe60eb75b65aaa22574b33f88223dc362fd8926116ba3e6aae021d63
客户端离线镜像 client/flutter_app/assets/persona/persona_v1_4.json 与 config 版字节一致。

覆盖场景：安慰用户、用户生气、用户沉默、专业问题、更主动、否定观点、学习回忆、来源冲突、删除记忆、不记录、身份四问（谁/生日/年龄/机器人）、总览类记忆问题、破角色黑名单命中。

用户已批准候选差异，结构门禁通过；真实智谱语义评测未执行（工作区无 Key），不以规则或 mock 结果替代，留待 scripts/probe_persona_regression.py --approve-test-api 由用户实测。
