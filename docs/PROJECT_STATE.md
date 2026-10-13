# 主项目交接：Astra-Logiphos/Xavier

截至2026-10-13，用户要求的九模块Windows改造已实现，三批真实Windows检查与ZIP发布通过。优先继续本仓库；完整Android后置，不擅自接入模型、语音或平台搜索。用户额度中断五小时后自动恢复不受当前工具支持，不能承诺自动唤醒；会话重新激活后依据本文件续接。

## 交付与证据

源码分支feature/module-1-local-backend，PR #2 https://github.com/Astra-Logiphos/Xavier/pull/2，未合并main。最终功能源码67ff31a。Windows最终运行38406409272：62后端/23Flutter全通过、analyze零问题、编译、普通启动、后台补排计划任务、一分钟原生通知入队/到期消费、打包BAT令牌复用/聊天记忆持久化/崩溃恢复/登录自启均通过。通知横幅和私人设备视觉验收仍由使用者执行。

ZIP批次1–3 companion-preview-22-1（61190768字节），4–6 companion-preview-23-1（61995576字节），7–9 companion-preview-26-1（62401802字节，下载/SHA256/内容与原生证明核对通过）。每包完整解压，无需安装Flutter/Python。第三包含全部九模块指南和改动文件清单。用户后续无需逐模块回复通过，可自动测试后继续；发布节奏每三个模块一包。

## 已实现

1. 仅127.0.0.1:8080本地后端、BAT便携Python、自动令牌复用、聊天/可审核记忆管理、登录自启与崩溃恢复。
2. 附件用户报告九区/九条情绪场景、时间问候/五类鼓励提醒/空状态、人设介绍；GLM系统模板预留，未调用。
3. 所有字体主题20/15/13、行高1.5、统一字重；系统/思源黑体/霞鹜文楷/思源宋体。本地OFL资产与许可证，google_fonts不运行时下载。用户明确授权MiSans替换OFL字体。
4–5. 猫耳少年立绘/人话摘要/两色系/十主题/独立插件/自动时间切换/静态与隐藏暂停；图库裁剪/长边1920/JPEG80/缩略图/遮罩/持久化。用户明确授权Windows使用image_picker+本地裁剪+Dart image替代不支持Windows的image_cropper/flutter_image_compress。
6–7. 最新要求foods.json指定jhyan-ux源，七字段1838条；226条能量缺失或超1000置空。可食部/营养超100也置空，未知不猜测。exercises.json为2024官方表公开Git blob校验镜像1111条/22类，非完整1144条。get_storage每天一条，饮食/运动Tab，实际克数、MET×kg×小时、体重/BMR/活动系数、净值/目标缺口、周月历史。不接USDA在线API。
8. flutter_local_notifications五类独立设置；Windows原生单次排八自然日+当前用户每日00:05/登录任务补排（关闭全部注销），Android源权限/接收器/desugaring，完整构建后置。Etc/UTC别名回归已修复（完整时区资料与UTC归一）。
9. 全量JSON备份/清空/恢复，包含后台records/settings/model_usage、get_storage、外观/提醒、照片/缩略图；凭据不导出；后端事务与有效人设门禁，客户端失败回滚。首次本地连接建议周备份。

## 开发环境与续接

现有checkout /workspace/Xavier，保留主仓库，不创建worktree。未授权代理分工，不spawn子代理。Python /workspace/tools/xavier-python/bin/python；Flutter3.35.7 /workspace/tools/flutter/bin/flutter。运行Flutter设置ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/tools/dart-state、XDG_CONFIG_HOME=/workspace/tools/config、PUB_CACHE=/workspace/tools/pub-cache、CI=true。后端测试python -m unittest discover -s tests -q，Flutter在client/flutter_app运行analyze/test。真实Windows构建仅GitHub托管runner，不虚构本机Windows结果。

环境安装与start_skill已保存草稿、未发布；当前实例验证已完成，新任务还原不宣称已验证。已知网络域storage.googleapis.com、api.github.com、results-receiver.actions.githubusercontent.com、pacompendium.com。Actions日志可读；artifact blob下载可能拒绝，错误重定向到/tmp并只输出原因，不打印临时签名URL。GitHubrelease ZIP下载可用。

Windows构建工作流在PR代码改动自动发布companion-preview-{run_number}-{attempt}；不要小改反复提交构建。编译失败需读诊断，原生通知门禁不得跳过。源码无云服务器方案，后端只本地。所有配色字号圆角粒子参数从assets/theme.yaml的YAML1.2 JSON兼容格式读取，用户外观覆盖持久化。无实机访问、无生产签名、无真人/通用LLM冒称。
