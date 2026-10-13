# GitHub 仓库复审 / 2026-10-13

目标：https://github.com/Astra-Logiphos/Xavier
分支：main；审计基线 commit：deca51569e210e9c4822428c206fd8a0025d24c2。
GitHub 连接已验证，递归 tree 完整返回，仅 LICENSE 一文件；保留现有许可证与提交历史。
根 AGENTS.md / SKILL.md 均返回 404；无 DeepWiki / Context7 / OpenCode MCP 配置，无业务源码、Flutter、Android、Windows、后端、数据库或工作流。对应工具未接入，不能伪称成功。

## 合并前目录规划与风险

将前次已测试源码加入 client/flutter_app、server 业务模块、data 模式与合成样例、docs、scripts、tests、四个 .github/workflows。新分支提交、草稿 PR，不直接覆盖 main。新 tree 使用已审计 base tree，保留 LICENSE。
当前仓库公开：仅提交代码/模板/合成样例，不提交真实聊天、数据库、缓存、数据集、权重或凭据。
Flutter SDK 仍未在本环境安装；实际 Flutter 测试需由 GitHub 托管 CI 验证。没有签名 Secrets 时不能构建正式 Android 包，也不发布假 Release。
免费规则模式不调用模型；真实模型免费额度、外部平台授权、真实语音尚未验证。人设语义回归和生产安全尚有边界，详见验收矩阵。

---

以下为连接 GitHub 前的云端目录审计历史，不能用于否定现在已验证的仓库连接。

# 仓库审计 / 2026-10-13

审计范围：当前云端工作目录 `/workspace/scratch/8b4934ccd23b`，没有访问用户电脑或私人账号。

| 检查 | 结果 |
|---|---|
| Git 仓库 / remote | `git rev-parse` 失败；没有 `.git`，无法识别当前 GitHub 仓库 |
| 根目录 AGENTS.md / SKILL.md | 创建之前均缺失 |
| DeepWiki / Context7 / OpenCode MCP | 云端配置为空；工具注册表无对应接口；缺失且未验证 |
| 现有业务、Flutter、Android、Windows、后端、数据库 | 无 |
| 现有工作流与配置 | 无工作流；保留云端已有配置，不纳入交付 |
| Flutter / Dart | 未安装，客户端构建待 GitHub 托管 runner 验证 |
| Python | 3.12.14 可用；采用标准库可离线测试 |
| GitHub 连接与发布权限 | 未提供，未提交、未推送、未发布 |

## 编码前目录规划

按用户要求建立 client/flutter_app、server 的 13 个业务模块、data/schemas/sample/official/community、docs、.github/workflows，另加 tests、scripts 与数据库迁移。Flutter 原生 runner 由固定版本 Flutter 在构建时生成；应用源码和 runner 配置脚本入库，不伪称已在 Windows/Android 编译。

## 风险与约束

1. 未挂载仓库：交付可导入源码包；必须连接目标仓库后才能提交和触发 Actions。不会凭空创建 remote 或声称修改现有仓库。
2. 免费回复：规则模式不调用模型、无模型费用，但不具备通用推理。云端算力、托管、带宽与真实模型的免费额度均不能保证永久。默认禁止付费 API。
3. 官方剧情为空：初始仅有用户要求的语气规范，不编造官方事实；人工提供有权使用的来源才能建立 canon。
4. 人设安全测试是结构与策略门禁，不足以证明真实模型绝无幻觉或语气漂移；模型语义回归待配置后人工与线上评估。
5. 小红书、Bilibili、公开网页自动抓取与搜索未授权：只做连接器能力声明和手动导入，不绕过平台限制。
6. 语音先实现 mock；按钮不会伪装录音或真实合成。
7. 后端为单用户部署原型：Bearer token、请求大小限制、参数校验；生产扩展需身份系统、限流、加密存储、备份删除策略和安全审计。
8. Android 签名必需；真实凭据只通过 Secrets。Windows 便携版未代码签名，安装包构建预留。
9. 不提交数据库、聊天原文、缓存、模型权重、凭据、官方完整素材或第三方完整原文。
10. 导入文本属于不可信数据，不能作为系统指令；只有人工批准的结构化特征参与人设。

完成本报告与规划后继续独立编码。外部连接与实际构建状态见 docs/unverified-capabilities.md。
