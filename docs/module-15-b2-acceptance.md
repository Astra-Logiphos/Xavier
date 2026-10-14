# 模块十五批次二最终验收报告

方案：输入即时显示，300ms仅合并草稿处理；缓存消息列表、稳定key、粒子层改为直接重绘。轻量/health成功间隔2秒，失败按4/8/16/30秒退避，窗口隐藏暂停；/status业务数据无定时轮询，启动、发送后、切页或窗口返回时刷新。记忆索引缓存300秒、排序移出整请求锁；编辑、删除、撤销同意、清空、恢复立即失效。没有修改prompt，没有新增依赖。

视觉：参考目录无图片，沿用外侧圆形40px头像、时间分组、圆润蓝紫气泡；不采用微信绿色/灰底/方形头像。theme.yaml仅新增performance，原主题色及背景定义逐项保持相同。高/中/低实际粒子为原数量50%/25%/0，低档关闭粒子、发光模糊与气泡模糊阴影；原数量滑杆保存基础值，避免反复减半。自动主题跨时段切换仍生效，普通分钟计时不再刷新聊天页。

头像复用file_picker与image库，等比压至长边512、JPEG质量80，复制进安装目录config/avatars/；只保存副本名称，不保存原图路径。上传优先于avatar.userPath，恢复默认后重新使用该配置。安装目录须可写；用户头像、语音、桌宠素材、数据库与backup均不打包。

start_all.bat先启动本地监督后端并验证带本机令牌的/status，未就绪不启动App，超时明确报错。双击后App自动连接；智谱系统环境变量保持原设置。环境变量说明已注明REQUIRE_API_CONFIRMATION可选false，你本机实际为false。

## 改动文件列表

由git diff --name-only 1757908→22a473d生成，共33个源码文件；安装载荷19个，完整安装相对路径、大小与SHA256均在ZIP内manifest.json。

- `./`：`.gitignore`、`start_all.bat`
- `.github/workflows/`：`build-windows.yml`
- `client/flutter_app/assets/`：`theme.yaml`
- `client/flutter_app/lib/`：`ambient_background.dart`、`api_client.dart`、`appearance.dart`、`avatar_store.dart`、`chat_page.dart`、`connection_monitor.dart`、`main.dart`、`performance_probe.dart`
- `client/flutter_app/test/`：`background_test.dart`、`performance_test.dart`
- `docs/`：`module-15-b1-acceptance.md`、`module-15-b2-acceptance.md`、`windows-model-environment.md`
- `docs/refs/chat-bubble/`：`README.md`
- `scripts/`：`build_frontend_patch.py`、`build_patch.py`、`bundle_windows_backend.py`、`check_artifacts.py`、`profile_windows.py`、`smoke_m15_b2.py`、`smoke_patch_bundle.py`、`start_all.py`
- `server/api/`：`app.py`
- `server/memory/`：`retriever.py`、`store.py`
- `tests/`：`test_frontend_patch.py`、`test_memory_cache.py`、`test_start_all.py`
- `tools/pack/`：`patch.ps1`

## 前后数据对比与测试结果

|项目|b1现状|b2实测/变化|
|---|---|---|
|默认主星粒子|40|高20 / 中10 / 低0，选择持久化|
|背景刷新|每帧创建AnimatedBuilder子树|CustomPainter重绘，静态图片与遮罩不随粒子重建|
|记忆索引|每次全表读取、重新分词|300秒复用；变更即失效；排序不持有请求锁|
|输入→绘制提交|未采集DevTools基线|平均9.217ms / 最差28.303ms，40次输入|
|打字时消息列表rebuild|未采集DevTools基线|0次|
|帧耗时|未采集DevTools基线|平均11.181ms / 最差24.898ms，191帧|
|构建 / 栅格平均耗时|未采集基线|0.504ms / 1.392ms|
|模拟后端回复→显示|未采集基线|44.99ms（非真实智谱）|

Windows profile实际运行同一聊天组件，20轮历史、40次控制器编辑；经DevTools使用的VM Service采集时间线。计时范围为控制器更新至Flutter绘制提交，未测实体键盘至显示器扫描延迟。原始数据：[performance-metrics.json](https://github.com/Astra-Logiphos/Xavier/releases/download/m15-b2/performance-metrics.json) / [DevTools时间线](https://github.com/Astra-Logiphos/Xavier/releases/download/m15-b2/devtools-timeline.json)。

Windows：python -m unittest discover -s tests -v **101项通过、零跳过**；flutter analyze **零问题**；flutter test **40项通过**。慢LLM挂起期间/status平均1.194ms、最差1.259ms（5次请求）。本地Linux同101项，5项Windows专用跳过；Flutter40项通过。

Windows真实编译、进程启动、通知检查、打包后端持久化与崩溃重启通过；头像导入→删除原图→新进程重开→恢复默认通过；start_all.bat后端就绪后才打开App且自动连接通过；无效端口等待超时、App不打开通过；补丁App运行拒绝→备份→应用→版本戳→独立revert.bat→字节与版本恢复通过。证据：[GitHub Actions 38551447348](https://github.com/Astra-Logiphos/Xavier/actions/runs/38551447348)。

**做不到工作区真实智谱首字<3s验收：这里没有可用Key，不能读取你电脑的系统变量。待你本机自测，尚未证明真实智谱达标。当前接口非流式，完整回复返回后才显示。** 三档外观效果及你电脑的输入体验仍属事后实机验收。

## 补丁交付

[下载m15-b2-patch.zip](https://github.com/Astra-Logiphos/Xavier/releases/download/m15-b2/m15-b2-patch.zip)：**4,580,819字节（4.58MB / 4.37MiB）**，19个载荷文件；未发整包。实际字节变化的原生插件DLL已纳入，未变化的Python/Flutter运行库排除。

SHA256：`7fc571d8c014bb3f9f4b13a15c6107072b4bae57e6d7474d7739f56765c1c5cd`。

分支codex/m15，独立tag m15-b2；源码/版本戳**m15-b2 ·22a473d**；前置**m15-b1 ·1757908**；原始底座**666e2e2**。应用一句话：关闭App、后端及监督程序，完整解压补丁到新目录，运行其中apply_patch.bat选择现有m15-b1安装目录，成功后双击安装目录start_all.bat。

ZIP内含独立revert.bat，回退本批到m15-b1；用户头像与数据保留。安装目录revert.bat回退当前最新批；有后续批次覆盖同一文件时，必须逆序回退，旧备份不删除。本批回退后若需重装，先将旧backup/m15-b2完整另存，避免同批备份覆盖保护阻止重新应用。最终数字与SHA以本报告和Release为准。

## 用户事后实测清单与缺陷清单

1. 外观→高/中/低切换，重开仍保留；原配色、背景不变，低档无粒子与模糊。
2. 设置→我的头像，选jpg/png；发消息后我方显示。关闭App、删除原图、重开仍显示；恢复默认有效。
3. 关闭后端与App，双击start_all.bat，只需一次操作；后端先就绪，App随后打开且显示本地已连接。
4. 发10条消息，输入即时，关闭重开历史正常；记录智谱实际响应速度。
5. 关闭App和后端，运行补丁目录revert.bat，版本恢复m15-b1 ·1757908；个人数据和头像副本保留。

B1-A连续10条、B1-B历史加载：自动回归通过，用户事后验收待反馈。UI-01图库缩略图装饰越界为现有问题，记录待下一批修复。真实朗读仍为模拟，已接受，SAPI后议。批次三人格草稿未批准前不进入prompt；按流水线继续第一段并在草稿与合并停点等待确认。
