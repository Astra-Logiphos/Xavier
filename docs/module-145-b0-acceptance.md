# 模块14.5批次零验收报告

分支：codex/m145；底座代码版本：666e2e2。自动验证通过，用户设备验收待确认；未合并主分支，未开始批次一。

## 改动文件列表

- .github/workflows/build-windows.yml
- .github/workflows/release.yml
- AGENTS.md
- client/flutter_app/lib/main.dart
- client/flutter_app/lib/version_stamp.dart
- client/flutter_app/test/version_stamp_test.dart
- docs/module-145-b0-acceptance.md
- scripts/build_patch.py
- scripts/bundle_windows_backend.py
- scripts/check_artifacts.py
- scripts/smoke_patch_bundle.py
- tests/test_patch_apply.py
- tests/test_patch_packaging.py
- tools/pack/apply_patch.bat
- tools/pack/patch.ps1
- tools/pack/revert.bat

## 前后数据对比

| 项目 | 底座 | 应用演示补丁 | 回退 |
|---|---|---|---|
| App版本戳 | m145-base · 666e2e2 | m145-b0 · 666e2e2 | 恢复底座 |
| docs/windows-preview.md | 原文 | 补丁演练文案 | 原文件字节/哈希恢复 |
| install-state.json | 底座元数据 | 本批manifest状态 | 原文件字节恢复 |
| 业务载荷文件数 | — | 1 | 1个原文件恢复 |
| theme.yaml/背景 | 原有值 | 0处变更 | 原有值 |

## 测试结果

- python -m unittest discover -s tests -v：本机69项，64通过、5个Windows专属跳过；随后Windows同一发现套件69项全部通过。
- flutter analyze：通过，零问题；flutter test：24项全部通过。
- 真实Windows编译、App启动、后端打包验证：通过。
- 真实底座App未关闭时拒绝补丁、文档替换/备份、版本戳更新、回退：通过；中文及空格目录、篡改/额外载荷、错误底座/路径穿越、重复应用拒绝：通过。
- 下载ZIP校验和、清单路径/大小/哈希、用户资产排除：通过。
- 工作流：https://github.com/Astra-Logiphos/Xavier/actions/runs/38509155166

## 产物与体积

m145-base.zip：62410096字节（约62.41MB），首个完整底座，包含Flutter运行时、便携Python及本地OFL字体；属于已批准首次底座例外。
m145-b0-patch.zip：4785字节（约4.79KB），小于1MB；载荷仅docs/windows-preview.md，无主题、DLL或运行时。
下载：https://github.com/Astra-Logiphos/Xavier/releases/tag/companion-preview-35-1

应用步骤：分别解压底座与补丁，关闭App和本地后端→运行补丁apply_patch.bat指定底座目录→重启检查版本与文档；关闭后运行底座revert.bat指定同目录验证恢复。

# 模块14.5批次零：首个底座与文档补丁

1. 将 m145-base.zip 完整解压到固定目录，打开 App→设置，预期版本为 m145-base · 构建提交短hash；功能沿用已交付版。
2. 将 m145-b0-patch.zip 解压到另一个目录。关闭 App 和本地后端，双击补丁目录 apply_patch.bat，输入底座目录。预期“补丁已应用，版本 m145-b0”。
3. 重启 App→设置，版本为 m145-b0 · 同一构建短hash；底座 docs/windows-preview.md 显示演练文案。演示文档源变化由 git diff --name-only 生成，未修改工程文档或主题；版本戳来自补丁manifest，提交hash标识实际打包工具和代码版本。
4. 关闭 App/本地后端，双击底座根目录 revert.bat，输入同一底座目录。预期版本及文档恢复底座原样，backup/m145-b0/保留原文件和原版本状态。
5. App运行中、错误底座、跳批/重复应用、额外载荷、文件大小/哈希不符均中止。回退只操作当前批次；被替换文件全部先备份，覆盖后再次逐项验证。

主题及背景完全不改动。用户语音/桌宠素材、数据库、backup永不进入包；安装状态和备份仅在用户指定的底座目录维护。补丁载荷只有 docs/windows-preview.md，未包含DLL或运行时。本批不实现14.5后端三项或模块十五。
