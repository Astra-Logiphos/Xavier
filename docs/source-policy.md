# 来源政策

所有 URL 和手动授权文字进入 pending_review；source_type 初始 unverified，不因用户选了平台就成为官方。
元数据：URL、标题、作者、发布时间、抓取/导入时间、平台、内容类型、来源版本、证据状态。未知作者/发布时间标记未提供，不伪造。URL 任务只保存链接，不获取正文。
声明分为 fact / interpretation / opinion / speculation，关键词分类置信度 0.45，fact 是“事实声明”而非已确认事实。每条含特征、必要摘录、来源 URL、平台、置信度、冲突候选和 review_status。

最多提取 20 条，每条声明最多 180 字、摘录最多 120 字，摘要最多 500 字。原始长文本不写入数据库；不下载视频或版权全文。不要导入密钥、私人评论或无权使用的素材。
小红书、Bilibili、PublicWeb 均为未授权的能力接口：不会模拟私人登录，不绕验证码、权限、付费墙或反爬，不对任意 URL 发请求。ManualImport 已测试。
`/sources` 查询是数据库内搜索，可按关键词、排除、platform、author、source_type、日期、evidence_status、review_status、min_confidence 过滤；不是实时网络搜索。客户端有关键词/排除/平台筛选，其他过滤通过 API 使用。
自动社区观点冲突检测尚未实现，人工通过 possible_conflicts 记录。有冲突不能批准。官方来源优先于社区解释，但没有编造官方语料用于判断。用户表达偏好不能成为剧情。

真实接入前需平台允许的官方 API/授权接口、应用凭据和适用权限；具体审批与费用以平台当时政策为准。当前未申请任何平台权限，也没有使用账号。
