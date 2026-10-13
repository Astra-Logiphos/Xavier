# API v0.1

单用户 JSON WSGI，服务端启动 `python -m server.api.app`，云端 HTTPS 前缀由反向代理提供。
除 `/health` 外必须 `Authorization: Bearer <AUTH_TOKEN>`。POST/PATCH/DELETE 使用 `Content-Type: application/json`。禁止把真实 token 写进文档、日志或仓库。
请求 ≤64 KiB，文本字段有上限。响应 200 成功；400 校验/能力未启用；401 未授权；404 未知接口；413 过大；501 未实现外部搜索；503 未配置身份；500 泛化内部错误。响应不缓存，无 CORS 开放，原生 Flutter 不依赖 CORS。

| 方法 | 路径 | 说明/关键字段 |
|---|---|---|
| GET | /health | 非敏感公开健康状态，无 Key 时可启动 |
| GET | /status | 当前人设版本、pending_sources、供应商、安全开关、连接器真实状态 |
| GET/PATCH | /settings | save_conversations、emotion_enabled、voice_enabled、language、reminders_enabled、reminders_paused |
| POST | /chat | text、mode、no_save、save_learning、api_confirmed，可指定 memory_id/memory_query |
| GET/POST | /memories | q 检索；kind、content、consent=true、confidence、source，敏感显式 sensitive_confirmed |
| PATCH/DELETE | /memories/{id} | 编辑 content/consent/confidence 或删除；不能删除其他 kind |
| GET/POST | /learning | topic、knowledge_points、consent=true |
| PATCH | /learning/{id} | mastered、unmastered、mistakes 文本数组；user_understanding 文本 |
| POST | /learning/{id}/review | 复习次数 +1 与下次时间 |
| GET | /learning/{id}/quiz | 基于已保存知识点的自测，不自动验证专业答案 |
| GET/POST | /checkins | category、自定义类别，local_date 可补卡；返回连续天数，重复日期类别幂等 |
| GET | /daily?date=YYYY-MM-DD | 日期聊天与规则摘要；不补造未保存对话 |
| PATCH | /emotion/{turn_id} | label，只有已保存轮次能修正 |
| GET/POST | /sources | 数据库搜索或手动导入，URL 不抓取 |
| PATCH | /sources/{id} | source_type、source_version、evidence_status，人工标记 |
| POST | /search | 默认关闭；启用后仍返回未授权/未验证，不能假装搜索成功 |
| GET/POST | /traits | 查看或新建候选 text、layer、source_id、confidence、possible_conflicts |
| PATCH/DELETE | /traits/{id} | text、paused、possible_conflicts；编辑后重审，删除清除历史对应特征 |
| GET/POST | /review | 待审核 source/trait；id、action=approve/reject/defer/conflict |
| GET | /persona | active PersonaVersion |
| GET | /persona/versions | 含版本记录 id 与 version_id，两者不同 |
| GET | /persona/diff?left={id}&right={id} | 使用数据库记录 id 比较 prompt |
| POST | /persona/rollback | id，创建新版本而非覆盖历史 |
| GET | /persona/export | json 与 markdown |
| GET | /persona/eval | 当前版 evaluation，含 report_markdown |
| POST | /persona/preview | text，静态示例，不调用模型、不修改版本 |
| POST | /voice/stt | text_fixture、language，模拟转写，无录音 |
| POST | /voice/tts | text、emotion、language，mock=true/audio_url=null，参数包含 speed/pitch/volume/pause |
| GET | /data/export | 全部个人 records 与非密钥设置 |
| DELETE | /data | confirmation=DELETE_ALL，清空当前数据库并重建初始无个人信息人设 |

## mode

chat、learning、professional、research、code、paper。专业模式当前没有真实知识检索；sources 始终为空，不伪造引用。

## 来源导入与过滤

POST 必填 title，至少有 https URL 或必要授权 text。其余 author、published_at、platform、content_type、source_version、summary。平台：manual/xiaohongshu/bilibili/public_web。初始 review_status=pending_review、source_type=unverified。
长文本仅提取必要候选与摘录，不保存完整 text。source.fetched_at 代表实际手动导入时间，不声称成功下载 URL。
GET 支持 q、exclude、platform、author、evidence_status、review_status、source_type、from、to、min_confidence。日期筛选为记录导入日期；发布时间未知时不能当可靠时间过滤。

## 人设与证据状态

layer：canon_persona/community_evidence/user_preference/interaction_style。
source_type：official/fan_opinion/unreliable/unverified。evidence_status：confirmed/plausible/disputed/rejected。canon 需要 URL + source_version + official + 已批准来源；community 要 confirmed/plausible。
interaction_style 还要 trigger_turn_id、scope、expires_at（未来带时区时间）；没有自动提取服务。
明确偏好可新建候选，批准后进入版本。用户不能以社区资料冒充显式偏好。门禁不代表语义模型已验证。

## 合成示例

```json
{"text":"今天学了深度学习","mode":"learning","save_learning":true,"no_save":false}
```

```json
{"title":"合成示例","url":"https://example.org/synthetic","author":"Synthetic","published_at":"未提供","platform":"manual","text":"我觉得温柔的表达适合陪伴。"}
```

```json
{"content":"喜欢星空","kind":"profile_memory","consent":true,"confidence":1.0}
```

此文档与源码为接口依据，不是平台连接成功证据。未来接入 Web/OpenAPI 框架时需保持隐私命令优先与同样的认证边界。
