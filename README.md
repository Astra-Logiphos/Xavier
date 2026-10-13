# 星回 · 沈星回风格智能体

[![Latest Release](https://img.shields.io/badge/Download-Latest%20Release-8899dd)](https://github.com/Astra-Logiphos/Xavier/releases/latest)

**当前交付为单用户后端原型与 Flutter 客户端。另提供独立的 Android 免费规则预览，非正式生产版。**
目标仓库：Astra-Logiphos/Xavier。源码通过独立分支与草稿 PR 提交；实际 CI 状态见 GitHub Actions。尚无 APK/Windows 正式 Release。
虚构 AI 互动角色，不是官方产品，不声称具有真实意识。默认 canon 数据为空。

## 先使用电脑版

在 [Build Windows](https://github.com/Astra-Logiphos/Xavier/actions/workflows/build-windows.yml) 成功的运行中下载 windows-release，完整解压后打开 xinghui_companion.exe；使用说明随包提供。未配置后端也可规则聊天和换背景。

## Android 预览（后续按需构建）

Android 开发 APK 已编译，但预览 Releases 上传遇到 HTTP 403，尚无正式下载 Release。当前先完善电脑版；预览工作流改为手动触发。打开即可聊天和换背景，无需配置模型 Key。预览是开发签名，长期记忆需要云端后端。发布状态以实际 Release 为准，详细说明见 [预览](docs/android-preview.md)。

## 你可以先做什么

- 不用模型 Key，运行免费规则模式：聊天演示、记忆管理、学习记录与回顾、打卡、日期回顾。
- 导入来源链接或授权文字，分开查看观点/事实声明候选，人工审核后生成分层人设版本。
- 明确提出“我希望你更主动”，形成待批准的 user_preference；支持暂停、恢复、删除、版本差异与回滚。
- 使用 Flutter 客户端选择星夜/月光/暖春主题，自定义背景、遮罩、卡片圆角和字号，导出主题参数。
- 通过服务端供应商接口接入 DeepSeek / 智谱。默认 API、可能收费调用、外部搜索关闭。
- 学习规则：独立的资料搜寻、手动添加、相处记忆；只有确认后的候选参与长期检索，重复跨日期反馈才能提出短期风格，见 [演进规则](docs/evolution-rules.md)。
- 语音和情绪接口：语音仅 mock，情绪为可修正的低置信度关键词候选。

## 后端启动（云端开发环境）

Python 3.12+，无第三方运行依赖。

```bash
export AUTH_TOKEN="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
python -m server.api.app
```

默认监听云端环境的 `127.0.0.1:8080`；不是访问用户电脑。没有 AUTH_TOKEN 时仅 health 可用；没有模型 Key 时可以启动并使用 mock。
`.env.example` 是模板，程序不自动加载 `.env`。部署平台通过环境变量注入。请勿把 token、Key 或数据库提交。
公开部署使用 HTTPS 反向代理，设置 `HOST=0.0.0.0` 并挂载持久卷，详情见 [部署](docs/deployment.md)。

## 测试与构建

```bash
python -m unittest discover -s tests -v
python -m scripts.eval_persona
```

Flutter 固定 SDK 3.35.7；原生 runner 由 `python scripts/bootstrap_flutter.py` 在云端生成。
本工作环境没有 Flutter SDK；GitHub Actions 已实际通过 Flutter analyze 与 Flutter test。Android/Windows 构建状态以 Actions 为准，正式 Android 签名尚待 Secrets。
后端已执行 **46 项离线测试通过**。真实模型、网页检索和语义回归未验证。
完整状态见 [验收矩阵](docs/acceptance-matrix.md) 和 [未验证清单](docs/unverified-capabilities.md)。

## 发布和下载

1. 审阅项目 PR 与 CI，合并到 main；已保留仓库原有 LICENSE。
2. 下载按钮已指向本仓库 Releases；必须成功发布后才有下载文件。
3. 配置四个 Android 签名 Secrets，运行 Test、Build Android、Build Windows。
4. 测试与构建通过后，推送 `v0.1.0` 标签。Release 工作流自动发布 APK、AAB、Windows ZIP 与 SHA256SUMS。
5. 点击上方 Latest Release 按钮：Android 下载 APK；AAB 用于应用商店，不能直接安装；Windows 下载 ZIP，完整解压后运行 exe。

未配置签名或构建失败时不发布。没有实际 Release 之前按钮没有可下载产物。
[后续操作指南](docs/user-guide.md) 包含从导入仓库、部署到换背景、审核、免费模式和下载的具体步骤。

## 目录

- `client/flutter_app/`：跨平台 Flutter 应用、外观系统、客户端测试。
- `server/`：api、providers、memory、persona、lorebook、source_search、source_import、review、learning、checkin、emotion、voice、migrations。
- `data/`：模式与合成示例，不含真实聊天、权重、数据集或官方完整素材。
- `docs/`：审计、API、架构、隐私、部署、验收、后续使用。
- `.github/workflows/`：测试、Android、Windows、发布；全部 GitHub 托管 runner。
- `scripts/`：runner 配置、回归报告、发布路径检查、下载链接配置。

## 还需完成

真实 STT/TTS 与客户端录音、已授权的外部搜索、模型语义互动风格提取、完整每日事件/约定/待办提取、通知调度、真实模型语义回归、Windows 安装包与签名、多用户身份认证、生产限流和数据库加密等尚未实现。
模型/托管免费额度与价格不能承诺；规则模式无模型费用，但不等于免费通用智能推理。
