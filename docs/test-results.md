# Windows 改造测试证明

| 批次 | 真实Windows工作流 | 后端 / Flutter | 交付 |
|---|---|---|---|
| 1–3 | https://github.com/Astra-Logiphos/Xavier/actions/runs/38394163472 | 56 / 12 全通过，analyze零问题 | companion-preview-22-1 |
| 4–6 | https://github.com/Astra-Logiphos/Xavier/actions/runs/38402112771 | 59 / 19 全通过，analyze零问题 | companion-preview-23-1 |
| 7–9 | https://github.com/Astra-Logiphos/Xavier/actions/runs/38406409272 | 62 / 23 全通过，analyze零问题 | companion-preview-26-1 |

三批均真实Windows编译、桌面启动、便携Python打包、BAT功能验证及产物检查通过。第三批原生证明 notification-smoke.json 确认后台计划任务实际补排、通知入队并于一分钟后由系统消费；visual_banner_verified=false，用户电脑横幅仍按指南验收。

最新版验证覆盖：150克食物实际UI录入、70kg慢跑30分钟262.5千卡与净值、get_storage落盘与每日快照、十主题/图库压缩/隐藏与静态暂停、全量JSON导出清空恢复（含真实JPEG字节）、SQLite事务回滚及人设门禁。11页和10主题截图为工作流 ui-review-screenshots 产物。

食品1838条/七字段，226条缺失或超界能量为空；非空energyKCal保证0–1000/100g，并保留来源哈希与转换摘要。运动1111条/22原始类别，保留代码/描述/MET，引用2024版公开镜像，不称完整1144条。

本机Linux后端62项中61通过、Windows专属1跳过；该项随后在Windows全部通过。完整Android二进制、真实模型/语音/自动平台搜索、生产签名及用户私人电脑验收没有被这些结果替代。

最终 ZIP 下载/内容/证明核对通过，62401802字节，SHA256：fbd4c320c76e161cc6ce4dd9994dad600556d9626fac4270a098c5b8821cfd78。最终功能源码67ff31a；后续说明文档提交未改变编译代码。
