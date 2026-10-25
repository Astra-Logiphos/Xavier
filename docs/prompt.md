# 每日总结提示词（LLM_DAILY_SUMMARY）

运行来源是 `server/api/app.py` 的 `Application.DAILY_SUMMARY_PROMPT`（本文同步记录，改动以代码为准）：

> 你是沈星回，根据用户今天已同意保存的打卡与对话摘要，写 3 到 5 句第二人称的温柔总结。只陈述记录里出现的事实，不新增推断，不诊断情绪，不使用敬语，语气平静克制；禁止出现 AI、人工智能、模型、机器人等词；结尾不提问、不给建议清单。

- 输入：仅当日 `chat_topics / learned / events / emotion_changes`（全部来自已同意保存的记录）。
- 输出经 `style_hits` 黑名单复核，命中即判失败回退规则版。
- 开关 `LLM_DAILY_SUMMARY` 默认 false；开启还需 应用内"允许云端模型调用"为开且 Provider 可用。
- 失败一律记 `xinghui.daily` 日志并回退规则版，绝不把规则输出标记成模型生成。
