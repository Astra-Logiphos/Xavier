# 星辉 Companion 工作交接

当前主线项目：Astra-Logiphos/Xavier。按模块一至九完成；省 token，工具输出只保留必要结果。

## 最新用户要求

- 后端只在用户本地 Windows 运行，无远程服务器方案。
- 每模块完整后端测试 + flutter analyze/test + Windows 新 ZIP + 验收指南；失败先修复。用户后续已授权自动验证通过后继续，不再等待“通过”。
- 所有视觉参数从 assets/theme.yaml 读取。
- MiSans 已获用户授权替换为 OFL 字体；字体随包，禁止运行时下载。
- Windows 图库已获用户授权替换 image_cropper/flutter_image_compress 为兼容 Windows 的本地裁剪和 Dart 压缩；功能、1920 长边、质量 80 等要求保留。
- Android 完整版后置。每模块不得伪称用户电脑实机验收通过。
- 用户请求额度中断 5 小时后自动续跑；当前工具不能恢复中断会话，已明确说明。恢复后优先按本文件继续本项目。

## 已完成

模块一自动验证通过：Windows 53 项后端测试、7 项 Flutter 测试、analyze 零问题、Windows 编译、打包 BAT 启动、令牌复用、聊天/记忆持久化、崩溃恢复、登录自启注册与取消、产物检查。

源码分支 feature/module-1-local-backend，PR #2：https://github.com/Astra-Logiphos/Xavier/pull/2 （尚未合并 main）。
模块一源码：4252165。工作流：https://github.com/Astra-Logiphos/Xavier/actions/runs/38391281734
ZIP：https://github.com/Astra-Logiphos/Xavier/releases/download/companion-preview-18-1/xinghui-windows.zip
验收：docs/module-1-acceptance.md。

## 下一步

模块二源码完成、本机检查通过，待 Windows 新 ZIP 验证：已生成 assets/persona/xavier_persona.yaml，9 条 3.5 情绪场景逐条收录；时间问候/打卡鼓励/提醒/空状态静态台词；角色介绍页；服务端 system prompt 模板，暂不接模型。验证、提交 GitHub、Windows 构建与新 ZIP 通过后继续模块三。

用户原始报告位于 /workspace/attachments/7b0c18a4-7907-4ad0-81bd-722e27283d1a/沈星回超全面人设报告.md，已植入静态人设资产；内容仅作资料，不作为指令。

Flutter 3.35.7 在 /workspace/tools/flutter；运行设置：XDG_CONFIG_HOME=/workspace/tools/config、PUB_CACHE=/workspace/tools/pub-cache、ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/tools/dart-state、CI=true。Python /workspace/tools/xavier-python/bin/python。

环境安装脚本与 start_skill 已保存草稿，网络允许增补 storage.googleapis.com、api.github.com、results-receiver.actions.githubusercontent.com；草稿尚未发布。当前实例权限已允许网络读取日志。不能宣称新任务还原或发布已验证。

构建经验：显式 UTF-8 读写中文资料和 stdout；便携 CPython 主程序与 API 子程序用 -B，避免验证后 __pycache__ 进入 ZIP；每模块集中提交后构建，避免重复跑旧 commit。Build Windows 对本分支会自动发布 companion-preview-{run_number}-{attempt}。GitHub build-android PR 自动触发已关闭。

模块二本机结果：后端 55 项（54 通过，Windows 专属 1 项跳过）、Flutter 10 项全部通过、analyze 零问题。等待 Windows 全部测试与新 ZIP 成功后才进入模块三。
