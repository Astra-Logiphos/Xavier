# 人设系统

初始版本 `persona-0001`，canon 基线 `canon-empty-0`。没有声称已收集官方剧情；初始语气来自用户的要求。

| 层 | 输入 | 生效条件 |
|---|---|---|
| canon_persona | 人工核对的官方摘要 | 关联已批准官方来源、URL、来源版本；人工批准 |
| community_evidence | 粉丝/公开资料的候选观点和事实声明 | 来源已审核；证据 confirmed/plausible，无冲突；特征人工批准 |
| user_preference | 用户明确要求 | 自动/手动建立候选；用户在审核中心批准；只改变表达方式 |
| interaction_style | 候选互动变化 | 触发对话 ID、置信度、范围、未来过期时间；人工批准；不自动生成 |

PersonaVersion 保存用户指定全部字段与 evaluation、snapshot、status。版本 ID 在单个数据库内递增，不是仓库 release tag。
批准、编辑、暂停、恢复、拒绝、来源标记和回滚会生成新版本与 change_summary。只有确定性策略检查通过才 active。模型语义测试状态明确为 unverified。
查看 `/persona/versions`、`/persona/diff?left=<record_id>&right=<record_id>`、`/persona/export`。
删除特征会清除历史快照对应文本，不通过回滚恢复已删除记录。来源被拒绝后关联特征撤销；版本重建不会将已拒绝来源恢复。

暂停使用 `/traits/<id>` PATCH paused=true，恢复 false。编辑后重新进入待审核；删除 DELETE。
静态预览不调用模型，不能代表沈星回真实效果。不要依赖静态预览判断实际语气漂移。

回归门禁覆盖来源、官方/社区区分、显式偏好、风格批准、身份/事实/隐私约束。十个回归场景保存在 data/sample/persona_eval_cases.json，有离线行为测试。报告可在审核中心导出 persona_eval_report.md；每版报告同时保存数据库，不将用户数据写入仓库。
