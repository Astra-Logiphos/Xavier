# UNATTENDED_REPORT — 语音播放（TTS）两阶段交付

日期：2026-10-24 · 分支 codex/m15 · 执行模式：无人值守自主

## 任务状态总览

| 任务 | 状态 | 一句话说明 |
|---|---|---|
| 第0步 基线测试 | ✓ | 141 测试全绿（2 个 alembic 用例按设计在无依赖环境跳过） |
| 第0步 push 链路验证 | **阻塞** | 旧 PAT 已失效（API 返回 Bad credentials），无人值守无法重新授权；空提交 db37077 留在本地 |
| 第0步 分支干净 | ✓ | 开始时仅验证用空提交，无未提交改动 |
| 阶段一 系统TTS·依赖 | ✓ | flutter_tts 4.2.5（pub.dev 实查：官方平台表含 Windows，不含 Linux） |
| 阶段一 气泡小喇叭 | ✓ | 仅 AI 气泡显示；朗读中变停止图标可中断；开关关闭时隐藏（widget 测试覆盖） |
| 阶段一 情绪→参数映射 | ✓ | EmotionVoice 常量表：rate 0.90–1.05、pitch≤1.00；未知情绪回退 neutral；7 组断言单测 |
| 阶段一 语音朗读开关 | ✓ | 服务端既有 voice_enabled 设置项，默认关；长按"朗读"菜单也改走真 TTS（原为模拟提示） |
| 阶段二 edge-tts 调研 | ✓ | 7.3.1，LGPLv3，非官方 Edge 朗读接口封装；docs/voice.md 已按 UNVERIFIED·可能随时失效标注 |
| 阶段二 EdgeTTSProvider | ✓ | mp3 bytes；缺库/空文本/网络任何失败抛 ProviderError，绝不静默换声 |
| 阶段二 /api/tts/speak | ✓ | 503(关)/502(失败)/413(超500字)/audio/mpeg(成功)；runtime/tts_cache 哈希缓存（runtime/ 已 gitignore） |
| 阶段二 TTS_ENABLED 默认 false | ✓ | Config 新字段 env 读取 |
| 阶段二 客户端回退 | ✓ | audioplayers 6.8.1；云端优先→失败自动回退系统 TTS；回退逻辑 5 个单测 |
| 阶段三 单测 | ✓ | 服务端 8 用例（含真实网络用例按设计跳过）+ 客户端 8 用例（映射/回退/按钮可见性） |
| 阶段三 flutter analyze/test | **[未验证·本机]** | 本机无 Flutter 工具链，无法本地跑；需 push 后由 CI 验证（当前 push 阻塞） |
| 阶段三 能力状态表 | ✓ | docs/voice.md：系统TTS=已实现；edge-tts=已实现(UNVERIFIED·非官方)；Mock=保留兜底 |
| 阶段三 README 徽章核实 | ✓ | shields.io 两枚徽章实测 200(image/svg+xml)；actions 徽章原用 github.com 域名本机不可达，已换成实测可渲染的 shields 版 |
| 真实 edge-tts 合成 | ✓ | 本机源码环境 TTS_REAL=1 全过（真实调用微软服务，约 32s） |
| 全量后端测试 | ✓ | 149/149：裸环境 OK(3 跳)、CI 等效环境 OK(1 跳) |

提交：db37077(链路验证空提交) → 4fbeeb2(feat: 客户端系统TTS) → 23d51cc(feat: 服务端edge-tts) → 本文档与 docs/README/关于页文案随 docs 提交。

## 岔路口决策记录

1. **push 链路失效**（第0步）：旧 PAT 已被轮换删除，GCM 无人值守弹不出授权。选择：不等待、不绕过（不留任何非交互获取凭据的尝试），全部工作本地完成后集中重试一次，失败则列入阻塞。影响：CI（含 flutter 验证）与远端备份推迟到凭据恢复。
2. **Windows 系统 TTS 能力标注**：pub.dev 实查 flutter_tts 4.2.5 官方平台表**包含 Windows**，故未降级为"仅 Android"；但本机无法运行 Windows 客户端实测出声，按红线在 docs/voice.md 与本文标注 Windows 实际效果【未验证】，并给出"实测无声→关开关即可"的回退说明。影响：如果 Windows 端插件实际表现不佳，用户关掉开关即可，无功能性损失（云端音色仍可用）。
3. **edge-tts 装进 requirements 但不进离线包**：离线打包运行时不 pip 安装任何依赖，云端音色仅源码运行环境可用。选择如实写明而非假装打包版可用。影响：打包版用户只有系统 TTS；要云端音色需源码运行。
4. **真实合成实证**：临时把 edge-tts+aiohttp 等轮子装入仓库内 runtime/pylibs（已 gitignore）跑 TTS_REAL=1。选择：做，拿真实证据而非只写"应可用"。影响：无仓库污染（目录已忽略）。
5. **/voice/tts 旧 mock 端点保留**：新真端点按任务用 /api/tts/speak，旧 mock 端点原样保留供既有测试。影响：无。

## 阻塞项（需要用户回来处理）

1. **推送与 CI 验证**：需你在 GitHub 生成新 PAT（Settings → Developer settings → Personal access tokens，勾 repo，7 天期），然后本机任意一次 git push 完成授权；之后把本地 4 个提交推上 codex/m15 并确认 Actions 全绿（backend+flutter 两个 job，flutter job 是本批客户端代码的首次编译验证）。
2. **Android 真机实测**：气泡小喇叭出声、语速音调是否合意（Windows 效果未验证，若无声按 docs/voice.md 处理）。
3. **edge-tts 音色试听挑选**：docs/voice.md 三条试听命令（云溪/云扬/云健），选定后设 TTS_VOICE。
4. （提醒）TTS_ENABLED 与客户端"云端音色"开关都默认关，首次使用需双开。

## 需要用户手动验证的事项

- 打开 设置→语音朗读 → AI 气泡旁出现小喇叭 → 点击朗读/停止。
- 开启 云端音色（源码运行 + TTS_ENABLED=true）→ 播放 mp3 音色 → 断开后端再点 → 应自动回退系统 TTS。
- Windows 客户端系统 TTS 是否实际出声（插件声明支持但未实测）。
