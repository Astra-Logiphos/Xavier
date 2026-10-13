# Windows 系统改造验收矩阵

| 模块 | 交付与检查入口 | 实测边界 |
|---|---|---|
| 1 本地后端 | BAT、便携Python、复用令牌、聊天/记忆CRUD、登录自启和崩溃恢复；module-1-acceptance.md | Windows打包BAT功能检查通过，用户电脑待验收 |
| 2 人设 | 用户报告结构化九区、九条情绪场景、静态问候/鼓励/提醒、角色介绍、模型模板；module-2-acceptance.md | 静态台词测试通过；未调用模型或冒充独立核实官方剧情 |
| 3 字体 | 20/15/13、1.5行高、统一字重、四种本地OFL/系统字体；module-3-acceptance.md | analyze和字体主题测试通过；MiSans经确认替换OFL字体 |
| 4 UI | 猫耳少年立绘、自然语言摘要、两套色系、主题字号、空状态；module-4-acceptance.md | 11页截图自检；用户设备仍待观察 |
| 5 主题图库 | 10主题、独立插件、自动时间切换、动态开关、本地裁剪1920/JPEG80/缩略图/遮罩/持久化；module-5-acceptance.md | 压缩及隐藏/静态暂停测试通过；Windows替代实现经确认 |
| 6 饮食 | 指定jhyan-ux来源1838条/七字段、模糊搜索、克/份、自定义、按日get_storage；module-6-acceptance.md | 226条未知/异常热量不估算；控件录入与公式测试通过 |
| 7 运动 | 2024镜像1111条/22类别、四类浏览、时长/体重/MET、净值/目标缺口/周月历史；module-7-acceptance.md | 不宣称完整1144条；70kg慢跑30分钟=262.5kcal控件测试通过 |
| 8 通知 | 五类开关/时间、人设静态文案、Windows原生排队+本地任务补排；module-8-acceptance.md | 原生Windows门禁全部通过；横幅需用户设备验收，完整Android后置 |
| 9 备份 | 全量JSON导出/清空/恢复，含后台和本机热量/设置/背景；module-9-acceptance.md | SQLite事务及真实文件/图片字节恢复测试通过；凭据不导出 |

一切后端只运行本机回环地址。三批 ZIP 按 1–3 / 4–6 / 7–9 发布，每批完成 analyze、全部后端/Flutter 测试、真实Windows编译与打包检查。当前状态与构建证据见 test-results.md 和 PROJECT_STATE.md，未将用户电脑验收等同托管构建检查。
