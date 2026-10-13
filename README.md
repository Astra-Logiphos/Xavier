# 星辉 Companion

Windows 本地陪伴应用。后端仅运行在使用者自己的 Windows 电脑，数据保存在本机 SQLite。默认规则回复，无需模型 Key；真实模型调用与人设植入不在模块一实现。

## 模块一使用

完整解压本次 Windows 包 → 双击 `start_backend.bat` → 打开 `xinghui_companion.exe` → 设置 → 连接本地后端。Windows 包携带 Python 运行时，无需另装 Python 或 Flutter。请使用对应模块一构建产物；旧 `windows-preview-8-1` 不包含本次功能。

详细操作见 [模块一验收指南](docs/module-1-acceptance.md)。聊天默认保存；不保存开关、敏感内容保护与记忆审核仍生效。应用重开会恢复已保存聊天。“他记得的事”支持查看、编辑、删除和手动添加。

## 本地源码开发

Python 3.12+。运行 `python -m pip install -r server/requirements.txt`，再双击根目录 `start_backend.bat`。令牌只在首次运行生成，保存在 `%LOCALAPPDATA%\XinghuiCompanion\backend`。数据库使用同一目录，改变解压路径不会重建个人数据。

`enable_backend_autostart.bat` 注册当前用户 Windows 登录自启；`disable_backend_autostart.bat` 取消。启动器监督后端崩溃并自动重启；首次启动连续失败三次则退出，提示检查日志。

## 验证与打包

- 后端：`python -m unittest discover -s tests -v`。
- Flutter 固定 3.35.7，在 `client/flutter_app` 运行 `flutter pub get`、`flutter analyze`、`flutter test`。
- Windows 构建使用 GitHub 托管 Windows runner，仅用于编译和测试，不运行用户的后端服务或保存用户数据。
- Build Windows 工作流会编译 App、捆绑 Python、测试实际 bat 的持久化和崩溃恢复，再上传新 ZIP。
- 所有颜色、字号、圆角与透明度默认值和范围来自 `client/flutter_app/assets/theme.yaml`（采用 YAML 1.2 兼容的 JSON 表示法）。

## 后续模块

按用户要求依次完成并逐模块验收。模块二至九、完整 Android 版、真实模型、语音和生产签名均未在模块一交付。虚构互动角色，非官方产品。
