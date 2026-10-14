# 模块十五批次一：聊天页外观重构

分支codex/m15；前置安装m145-b1 · b2a570f，底座666e2e2。真实智谱三轮引用前文与用户实机10条消息待用户自测。模块14.5已合并main，补丁链正常；本批自动验收通过，补丁代码版本1757908；尚未合并，等待用户安装实测。

## 方案摘要与参考对齐

开工已读取AGENTS.md；docs/refs/chat-bubble、cute-ui、pet无图片或README。本批对齐微信的左右分边、外侧40px头像、超过5分钟时间戳和70%最大宽度；不采用微信绿色气泡、灰色页面背景、方形头像。theme.yaml与既有主题/背景保留原值。默认20px圆角、圆形头像、轻微阴影；我的气泡从现有主题主色保持色相/饱和度调低亮度，白字对比度至少4.5:1；支持可读的显式固定色。对方浅色白、深色#2F2F2F。

config/bubbles.yaml为Windows实际配置入口，JSON记法属于YAML 1.2；使用项目现有解析方式，无新依赖。client/flutter_app/config/bubbles.yaml由构建同步，作内置默认资源；Windows启动优先读安装目录config/bubbles.yaml。皮肤名称、对齐、宽度、头像路径/形状/尺寸、字体主题引用、颜色、圆角、边距、时间间隔、阴影、输入栏与滚动动画参数均在配置。外部配置无效时设置页给出错误并使用内置默认；对比度不足的白字固定色拒绝生效，避免不可读。

拆出ChatPage，列表按消息渲染，连续同侧且未跨时间分组只显示首条头像，输入栏固定且支持多行，新消息滚到最新。默认对方头像由现有CharacterPortrait生成，未引入外部素材；我的头像为可替换占位图。

消息和草稿长按/右键菜单：复制、保存到记忆、朗读、本轮不保存、同意保存学习记录。已保存轮次选择不保存需确认，撤销该轮聊天及候选、重算摘要，单独批准的长期记忆保留；草稿菜单开关仅作用下一轮；发送中的消息选择不保存，会在回复完成后撤销保存。学习菜单显式保存所选文本，未默认记录。朗读沿用现有mock接口，真实语音尚未开放。模式与单次API确认迁到设置页，请求开始即消耗确认（包括失败调用）；Key留服务端环境变量。

## 前后对比

|项目|之前|之后|
|---|---|---|
|消息|用户标题与回复混在卡片|独立左右气泡＋外侧圆形头像|
|时间/分组|无时间戳|>5分钟居中显示，同侧分组合并头像|
|流程/调试|保存状态、模式、按钮、朗读图标直接显示|聊天页清理，菜单/设置承担操作，调试状态仅日志|
|输入|单行布局并列模拟麦克风|固定多行圆角输入框＋发送键|
|皮肤|需改代码|编辑安装目录config/bubbles.yaml，重启生效|
|API确认|聊天页按钮|设置模型状态区单次确认|

## 测试与证据

本机验证：后端91项（86通过、5项Windows专属跳过），Flutter34项通过，flutter analyze零问题。Windows：后端91项全部通过，0跳过；Flutter34项通过，flutter analyze零问题。Windows真实编译、启动、通知回归、打包后端启动/持久化/崩溃重启通过。真实补丁应用、备份、设置版本戳、外部bubbles.yaml改色及进程重启、回退恢复m145-b1通过。下载后SHA256、载荷文件数、大小和逐文件哈希验证通过。

工作流：https://github.com/Astra-Logiphos/Xavier/actions/runs/38529795335

Windows Flutter测试渲染图：Release中的page-1.png、m15-chat-light.png、m15-chat-dark.png；本机亦已逐页查看截图，无聊天页流程按钮、模式横幅、保存状态或JSON。真人电脑视觉与真实智谱对话仍待用户实测。

## 补丁与版本

m15-b1-patch.zip：**4,580,554字节（约4.58MB / 4.37MiB）**，21个载荷文件，小于20MB。主要是12,108,720字节的未压缩data/app.so；仅字节变化的原生插件DLL亦保守纳入。未变化的Flutter引擎、Python、字体排除。

底座666e2e2，前置m145-b1 · b2a570f，manifest.previous_patch=m145-b1；新版本m15-b1 · 1757908。

下载：https://github.com/Astra-Logiphos/Xavier/releases/download/companion-preview-42-1/m15-b1-patch.zip

SHA256：5bb62e72f2b88d50f833f1764b7e6586e8c1f10951687a4f6b93acf09b8c4ace。测试覆盖布局/头像/时间分组/菜单、颜色派生与固定覆盖、文件重载、历史恢复、10条mock发送、设置区单次API确认及聊天撤销隐私、补丁前置链/运行时排除。截图包含浅色/深色聊天及全页面自检。

## 应用步骤

1. 本机保持m145-b1 · b2a570f。关闭App和本地后端及监督程序。
2. 独立解压m15-b1-patch.zip，双击补丁根部apply_patch.bat，输入原安装目录；不需重下底座，不直接覆盖整个目录。
3. 预期“补丁已应用，版本m15-b1”；重开App→设置，版本显示m15-b1 · 1757908。
4. 双击原start_backend.bat，设置连接本地后端。回退时关闭程序，运行安装目录revert.bat，恢复m145-b1 · b2a570f；备份保留。

用户语音、桌宠素材、数据库、backup不进入补丁。Python运行时沿用前置补丁；其余安装文件逐字节比较，仅变化文件入包，未变化DLL/字体/运行时排除。git diff --name-only用于源码变更清单。

## 用户实测清单

- 发10条消息：输入流畅、发送后看到最新消息、历史加载、我右他左且头像在气泡外侧。
- 间隔超过5分钟发送，时间戳居中；同侧连续消息只保留首条头像。
- 长按或鼠标右键消息，五项菜单齐全；复制可粘贴；保存记忆后在记忆页看到；学习记录在学习页看到；撤销保存后重启不再加载该轮。
- 关闭App，将安装目录config/bubbles.yaml中companionLightColor改为#E5DCF6或userColor改为#6A4EA1，重启在适用浅色主题看到颜色变化。所有主题与背景保持原有值。我的头像可通过avatar.userPath替换为本机图片路径；JSON记法建议用正斜杠，例如C:/Users/你的名字/Pictures/me.png。
- 设置模型状态区确认下一轮模型调用，回聊天发送；真实智谱三轮引用前文仍标注待用户自测。
- 真实语音尚未开放，菜单朗读不会宣称已生成声音。

## 永久环境变量

见[Windows系统级永久设置](windows-model-environment.md)。Win+R→SystemPropertiesAdvanced→环境变量→下半部系统变量，设置ZHIPU_API_KEY等，检查同名用户变量覆盖，重启后免每次手输。

## 改动文件清单

没有修改theme.yaml、AGENTS.md或用户资产。完整源码变更如下：

- .github/workflows/build-windows.yml
- client/flutter_app/lib/main.dart
- client/flutter_app/lib/api_client.dart
- client/flutter_app/lib/chat_page.dart
- client/flutter_app/lib/bubble_config.dart
- client/flutter_app/pubspec.yaml
- client/flutter_app/config/bubbles.yaml
- client/flutter_app/assets/characters/default.png
- config/bubbles.yaml
- client/flutter_app/test/chat_page_test.dart
- client/flutter_app/test/chat_flow_test.dart
- client/flutter_app/test/history_restore_test.dart
- client/flutter_app/test/ui_screenshots_test.dart
- server/api/app.py
- server/model_config.py
- tests/test_chat_privacy.py
- tests/test_frontend_patch.py
- scripts/bootstrap_flutter.py
- scripts/build_patch.py
- scripts/build_frontend_patch.py
- scripts/bundle_windows_backend.py
- scripts/smoke_patch_bundle.py
- docs/refs/chat-bubble/README.md
- docs/windows-model-environment.md
- docs/module-15-b1-acceptance.md

补丁前置版本b2a570f之后的模块14.5收尾文档（两批报告及docs/module-145-final.md）亦按git diff纳入文档载荷；不重新分发底座。
