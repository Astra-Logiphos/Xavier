# 星回 Companion（Xavier）

[![Release](https://img.shields.io/github/v/release/Astra-Logiphos/Xavier?include_prereleases&sort=semver&label=Release)](https://github.com/Astra-Logiphos/Xavier/releases)
[![Build Windows](https://github.com/Astra-Logiphos/Xavier/actions/workflows/build-windows.yml/badge.svg)](https://github.com/Astra-Logiphos/Xavier/actions/workflows/build-windows.yml)

Windows 本地陪伴应用。后端仅运行在使用者自己的 Windows 电脑，数据保存在本机 SQLite。默认规则回复，无需模型 Key；真实模型调用由应用内"允许云端模型调用"开关控制，Key 只配置在本机。

## Latest Release 下载方法

1. 打开 [Releases 页面](https://github.com/Astra-Logiphos/Xavier/releases)，取最新 prerelease（当前交付链：底座 `m145-base` + 增量补丁，最新批次见 Release 标题）。
2. 全新安装：下载 `m145-base.zip` 完整解压；已有底座：下载最新 `m15-XXXX-patch.zip` 增量补丁。
3. 校验：下载同 Release 的 `SHA256SUMS.txt`，本地 `certutil -hashfile <补丁>.zip SHA256` 与其中哈希逐字符一致才继续。
4. 增量补丁解压后双击 `apply_patch.bat`（需已安装前一批次；补丁链会拒绝跳批或重复应用）。
5. 启动：双击 `start_all.bat`（或 `start_backend.bat` + `xinghui_companion.exe`）→ 设置 → 连接本地后端。

## GitHub Actions 手动构建方法

1. 打开 [Build Windows 工作流](https://github.com/Astra-Logiphos/Xavier/actions/workflows/build-windows.yml) → **Run workflow**。
2. 分支选 `codex/m15`；`delivery_mode` 选 `frontend_patch`；`patch_batch` 选目标批次（如 `m15-b3a`）。
3. 运行后等待 backend + windows 两个 job 完成（约 15-25 分钟）。
4. 成功后自动创建对应 tag 的 prerelease，附 `*-patch.zip`、`SHA256SUMS.txt` 与界面截图；构建产物同时出现在 run 的 Artifacts（`windows-release`）。
5. 该流程会串联全部前置补丁、在真实 Windows runner 上验证应用/回滚再发布；普通 push 只跑测试不打包。

## 模块一使用

完整解压本次 Windows 包 → 双击 `start_backend.bat` → 打开 `xinghui_companion.exe` → 设置 → 连接本地后端。Windows 包携带 Python 运行时，无需另装 Python 或 Flutter。请使用对应模块一构建产物；旧 `windows-preview-8-1` 不包含本次功能。

详细操作见 [模块一验收指南](docs/module-1-acceptance.md)。聊天默认保存；不保存开关、敏感内容保护与记忆审核仍生效。应用重开会恢复已保存聊天。“他记得的事”支持查看、编辑、删除和手动添加。

## 本地源码开发

Python 3.12+。运行 `python -m pip install -r server/requirements.txt`，再双击根目录 `start_backend.bat`。令牌只在首次运行生成，保存在 `%LOCALAPPDATA%\XinghuiCompanion\backend`。数据库使用同一目录，改变解压路径不会重建个人数据。新库在装有 alembic 的环境走版本化迁移，离线打包运行时自动退回同一份 SQL 基线（见 `server/migrations/__init__.py`）。

`enable_backend_autostart.bat` 注册当前用户 Windows 登录自启；`disable_backend_autostart.bat` 取消。启动器监督后端崩溃并自动重启；首次启动连续失败三次则退出，提示检查日志。

## 验证与打包

- 后端：`python -m unittest discover -s tests -v`。
- Flutter 固定 3.35.7，在 `client/flutter_app` 运行 `flutter pub get`、`flutter analyze`、`flutter test`。
- Windows 构建使用 GitHub 托管 Windows runner，仅用于编译和测试，不运行用户的后端服务或保存用户数据。
- Build Windows 工作流会编译 App、捆绑 Python、测试实际 bat 的持久化和崩溃恢复，再上传新 ZIP。
- 所有颜色、字号、圆角与透明度默认值和范围来自 `client/flutter_app/assets/theme.yaml`（采用 YAML 1.2 兼容的 JSON 表示法）。

## 后续模块

按用户要求依次完成并逐模块验收。完整 Android 版、真实语音和生产签名尚未交付。虚构互动角色，非官方产品。
