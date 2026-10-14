# Windows系统级永久智谱环境变量

模型Key只在本机后端使用。以下设置写入Windows“系统变量”，重启后仍保留；需要管理员权限。

1. 关闭星辉App和本地后端，包括监督程序（Ctrl+C）及已有自启实例。
2. 按Win+R，输入 `SystemPropertiesAdvanced`，回车；点击“环境变量”。
3. 在下半部分“系统变量”点击“新建”或“编辑”，逐项设置：

|变量名|变量值|
|---|---|
|ACTIVE_PROVIDER|zhipu|
|ZHIPU_BASE_URL|https://open.bigmodel.cn/api/paas/v4|
|ZHIPU_MODEL|glm-4-flash|
|ZHIPU_API_KEY|粘贴自己的Key（不要截图、提交仓库）|
|API_ENABLED|true|
|REQUIRE_API_CONFIRMATION|true|
|ALLOW_PAID_API|true|

4. 检查上半部分“用户变量”里有没有同名旧变量；同名用户变量会覆盖系统值，删除旧项或改成一致。不要修改AUTH_TOKEN，它由启动器在本地生成复用。
5. 所有窗口逐级点“确定”，重启Windows。双击现有底座start_backend.bat；若之前已启用本地后端自启，则使用自启实例，避免重复启动。
6. 打开App→设置→连接本地后端。模型状态预期“zhipu / glm-4-flash”；启用“同意下一轮使用模型”后回聊天发送一次，确认项随后自动关闭。

验证变量时不要打印Key；可在重启后的PowerShell输入 `[bool]$env:ZHIPU_API_KEY`，预期True。Key变量缺失/无效不会自动回退到付费供应商。

ALLOW_PAID_API=true明确允许可能收费的调用，本批保留费用门禁，不保证供应商免费额度。系统级变量不是加密凭据库，同机进程可能读取；如果仅自己的Windows登录使用后端，可改用“用户变量”，但本指南按要求提供系统级步骤。不要把Key写进bat、项目文件或补丁包。
