# 审核步骤

1. 来源页面导入链接/必要授权文字，查看声明、摘录与元数据。
2. 人工核对原始出处，标记 official / fan_opinion / unreliable / unverified；官方需 source_version。
3. 审核中心批准来源或拒绝、暂缓、冲突；批准来源本身不会写入正式人设。
4. 添加有来源特征，填写 source_id 和 layer。canon 必须是官方来源；社区观点选择 community_evidence。
5. 查看候选 text、证据、置信度、冲突。人工解决冲突后批准。
6. 系统生成 PersonaVersion、change_summary、回归报告；策略检查失败版本 blocked，原版继续 active。
7. 查看版本记录、比较 prompt、导出 Markdown/JSON。若语气不合适可暂停条目或回滚。

用户“我希望你…”会生成显式偏好候选，批准后生效。社区内容不能直接进入 user_preference。
互动候选风格须带 trigger_turn_id、scope、expires_at；自动提取未接入。不要把一次情绪当永久特征。
回归报告的通过仅代表结构/策略检查，不代表真实模型完全一致；发布前实际运行十个场景并人工检查来源、专业事实和语气。
