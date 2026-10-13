# 记忆与每日记录

保存种类：conversation_turn、daily_summary、profile_memory、episodic_memory、relationship_memory、learning_memory、user_preference_memory。UTC 时间由服务端生成；日期绑定 USER_TIMEZONE，默认 Asia/Shanghai。
canon 只在人设层，不进入个人记忆。检索条件：明确同意、approved、置信度至少 0.8、未暂停。低置信度保留 pending_review，不参与检索；目前通过手动编辑 confidence 确认，没有自动知识验证。

聊天保存默认关闭。打开后只保存非敏感、未标记 no_save 的轮次。“这句话不要记住 / 不要记录”优先阻止持久化。敏感检测是保守关键词启发式，不承诺检测所有敏感信息；默认关闭自动聊天保存是主要保护。
“记住这件事：内容”视为明确同意；敏感内容仍需专用 API 的 sensitive_confirmed=true，客户端默认不提供一键绕过。
“忘记这件事”需要 memory_id 或在记忆页面明确选择。无目标不会猜测删除。
“今天学了深度学习”在勾选同意保存学习时进入 learning_memory，否则提示同意；未来查询只使用实际已保存学习主题。

按日期查看 `/daily?date=YYYY-MM-DD`。规则摘要包含近期话题、学习、情绪候选和当天偏好；事件、约定、待办、未完成话题由保守规则提取为候选，保留 source_turn_id 和置信度；不把候选当确定事实。摘要由聊天保存/学习写入/日期查看触发，没有后台每日定时调度。
删除记忆从 records 物理删除，secure_delete 与 VACUUM 用于当前数据库；没有向量索引，所以不会残留检索结果。云备份、平台快照和用户导出需另行处理。删除全部数据重建不含个人信息的初始人设。
