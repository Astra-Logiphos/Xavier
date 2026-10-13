# 沈星回智能体项目技能说明

1. 先阅读 AGENTS.md、docs/AGENTS_MISSING_REPORT.md、docs/architecture.md 与 docs/privacy.md。
2. 核心人设更新走 review → version draft → deterministic regression → active。默认 canon 为空。
3. 新接入服务实现 provider/connector 接口，声明费用、权限和未验证状态，使用离线 mock 测试。
4. 默认不自动保存对话。用户明确授权保存的学习记录才进入 learning_memory。敏感信息必须显式手动确认。
5. 每项功能同时更新 API、客户端入口、测试、操作说明和未验证清单。
6. 使用 release tag 发布；无签名 Secrets 禁止生成假正式 Android 产物。
