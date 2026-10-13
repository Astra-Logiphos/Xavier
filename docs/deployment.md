# Windows 本地后端与构建

后端只允许监听使用者电脑的 `127.0.0.1:8080`。不配置远程服务器或反向代理。

下载包含 Python 的模块一 Windows 包，完整解压，双击 `start_backend.bat`。令牌、数据库和日志保存在 `%LOCALAPPDATA%\XinghuiCompanion\backend`。首次启动创建令牌并默认开启聊天保存，后续复用并保留用户的保存选择。

登录自启：双击 `enable_backend_autostart.bat`；取消：双击 `disable_backend_autostart.bat`。目录移动后重新注册。后端进程崩溃后监督程序会重启，关闭监督程序则停止。

源码开发使用 Python 3.12+，先安装 `server/requirements.txt`（Windows 时区数据），再运行根目录 bat。`.env.example` 仅用于说明变量，程序不自动读取它；真实模型 Key 只能在本机服务端环境配置，不放客户端或公开仓库。

Windows CI 只执行编译和测试，生成带 App、Python 与后端源码的便携 ZIP。未将应用服务放在 CI 长期运行。使用流程与逐项检查见 [模块一验收](module-1-acceptance.md)。
