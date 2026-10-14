# 模块十五批次二追加：双侧头像验收报告

## 方案摘要

保留已交付批次二所有功能，复用现有文件选择器、等比压缩和 AvatarStore，仅增加独立角色槽。设置页“我的头像”与“他的头像”分别上传 JPG/PNG，长边上限512、JPEG质量80继续读取theme.yaml既有配置。复制到安装目录config/avatars/，SharedPreferences仅存受控文件名，恢复默认只删除对应槽的副本。兼容avatar.userPath与avatar.companionPath，布局和样式仍读bubbles.yaml；主题色和背景不改。无需新增依赖。

此补丁为m15-b2a追加批，不标记批次三完成、不启用人格草稿。后续m15-b3以本批作为前置。人格方案与8轮示例仅为待审文档。

## 改动文件列表

- `.github/workflows/build-windows.yml`
- `client/flutter_app/lib/avatar_store.dart`
- `client/flutter_app/lib/chat_page.dart`
- `client/flutter_app/lib/main.dart`
- `client/flutter_app/lib/version_stamp.dart`
- `client/flutter_app/test/performance_test.dart`
- `client/flutter_app/test/version_stamp_test.dart`
- `docs/module-15-b2-acceptance.md`
- `docs/persona/fewshot_examples.md`
- `docs/persona/prompt_optimization_proposal.md`
- `docs/refs/chat-bubble/README.md`
- `scripts/build_patch.py`
- `scripts/smoke_m15_b2.py`
- `scripts/smoke_patch_bundle.py`
- `tests/test_frontend_patch.py`
- `tools/pack/patch.ps1`
- `docs/module-15-b2a-acceptance.md`

## 前后对比

| 项目 | m15-b2 | m15-b2a |
|---|---|---|
| 设置头像上传 | 仅我的头像 | 我的/他的独立上传与恢复 |
| 原图删除与重启 | 用户头像副本可用 | 两个角色副本均可用 |
| 角色重置互相影响 | 单槽 | 重置他的头像保留我的头像 |
| 默认路径兼容 | userPath/companionPath | 两者保留，上传优先、重置恢复配置 |
| 主题色、背景、后端与运行时 | 既有实现 | 不修改 |
| 人格与记忆调用 | 原逻辑 | 不修改，草稿不注入 |

## 测试结果

本机python -m unittest discover -s tests -v：102项通过，其中5项Windows专属在Linux跳过；最终Windows结果以发布完成后的本文/Release更新为准。flutter analyze零问题、42项Flutter测试通过；Windows编译、双侧头像原生跨进程持久化、start_all与应用/备份/独立回退均须通过后发布。

性能指标沿用m15-b2实测：40次输入列表零rebuild、输入至绘制提交最差28.303ms。新增回归覆盖头像更新后的列表缓存失效与默认恢复；未把这些指标称为真实键盘到屏幕延迟。真实智谱首字<3秒本工作区做不到：无用户电脑的Key；仍待用户实测，不以mock替代。

## 补丁与应用步骤

前置：必须已安装m15-b2 · 22a473d；原始底座666e2e2保持不变。若仍是m15-b1 ·1757908，先安装m15-b2，再本批，禁止跳批。

关闭App与本地后端，完整解压m15-b2a-patch.zip，双击本补丁目录的apply_patch.bat并输入完整安装目录；完成后双击安装目录start_all.bat，在设置页检查版本m15-b2a。回退时关闭App与后端，运行本补丁目录revert.bat，恢复m15-b2；已上传头像属于用户内容，补丁与回退均不打包或删除。

补丁大小、SHA256、源版本hash与Windows结果将在发布完成后填写，下载入口：https://github.com/Astra-Logiphos/Xavier/releases/tag/m15-b2a 。不会交付整包；排除config/avatars、语音、桌宠素材、数据库与backup，未变DLL与运行时不打包。

分支：codex/m15；独立tag：m15-b2a。本批不合并主分支。现有UI-01图库缩略图装饰越界仍记录在缺陷清单，将在后续批次修复；不把现有缺陷称为本批已解决。

## 用户事后实测清单

1. 设置→他的头像→上传他的头像，选JPG/PNG；发一条消息，左侧头像显示所选图，右侧不变。
2. 删除原图、关闭App后用start_all.bat重开；他的头像仍在，历史仍正常。
3. 同时设置我的头像与他的头像，点恢复他的默认头像；左侧恢复配置默认，右侧保留上传图。再验证我的头像恢复默认。
4. 检查主题与背景不变、三档动效持久化、10条连续发送与历史加载；发现缺陷随下一批修复。
5. 关闭App与后端运行本补丁revert.bat，设置版本恢复m15-b2；再次应用本批可恢复新功能。
6. 智谱真实跨轮对话与响应时间由用户实测；本工作区不请求上传Key。

## 保留的待办与停点

批次三第一段已起草：docs/persona/fewshot_examples.md与docs/persona/prompt_optimization_proposal.md。用户逐句审核前，不修改运行中的prompt。真实GLM三轮基线缺Key，已在方案标明；现有mock原文只作补充，不声称真实模型结果。其他批次、批次三首段合并时点与最终收尾照总纲执行。真实朗读仍为此前已接受的模拟限制，不在本补丁新增SAPI。
