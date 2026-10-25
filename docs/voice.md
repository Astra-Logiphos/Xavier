# 语音朗读（TTS）

## 能力状态表

| 能力 | 状态 | 说明 |
|---|---|---|
| 系统朗读（flutter_tts） | 已实现 | 气泡旁小喇叭按钮 + 长按菜单"朗读"，走设备系统 TTS，离线、无 Key、默认关（设置→语音朗读） |
| 云端音色（edge-tts） | 已实现 · **UNVERIFIED · 非官方接口 · 可能随时失效** | 后端 `TTS_ENABLED=true` + 客户端"使用云端音色"开关（默认关）；失败自动回退系统 TTS，绝不静默换声 |
| Mock STT/TTS | 保留兜底 | `/voice/stt`、`/voice/tts` 仍是模拟实现，仅测试用 |

## 系统朗读（阶段一）

- 依赖 `flutter_tts 4.2.5`。插件官方平台表：Android、iOS、macOS、Web、**Windows**；Linux 不支持。
- **诚实结论**：Windows 在插件官方支持列表中，但本任务未能在本机运行 Windows 客户端实测出声效果——Windows 端朗读效果为【未验证】。Android 端为插件主要支持平台。若你实测 Windows 无声，可关闭"语音朗读"开关隐藏按钮，或只用云端音色。
- 情绪 → 朗读参数映射（客户端常量 `EmotionVoice`，附单测）：语速 0.90–1.05，音调始终 ≤1.00（温柔沉稳）；sad/tired 0.90·0.88，excited 1.05·0.98，未知情绪回退 neutral。
- 完全离线，不依赖后端与任何 Key；仅朗读当前气泡文本。

## 云端音色 edge-tts（阶段二）

> **UNVERIFIED · 非官方接口 · 可能随时失效**：edge-tts（LGPLv3，社区维护，与微软无关联）是对微软 Edge 浏览器"大声朗读"在线接口的逆向封装，微软未提供任何稳定性承诺，接口变更即失效。合成文本会发送至微软服务，见 privacy.md。

开启方法（源码运行）：

1. `pip install -r server/requirements.txt`（含 edge-tts 7.3.1）。
2. 后端环境变量 `TTS_ENABLED=true`（默认 false）；音色 `TTS_VOICE`（默认 zh-CN-YunxiNeural）。
3. 客户端设置 → 打开"语音朗读"和"使用云端音色"。播放失败（未连接/接口失效/网络问题）自动回退系统 TTS。
4. 离线打包运行时未捆绑 edge-tts：云端音色仅限源码运行环境；打包版用系统 TTS。

试听与挑音色（**候选 3 个中文年轻男声，请自行实测挑选，不代拍板**）：

```powershell
edge-tts --voice zh-CN-YunxiNeural    --text "嗯，慢慢说。我是星回。" --write-media yunxi.mp3
edge-tts --voice zh-CN-YunyangNeural  --text "嗯，慢慢说。我是星回。" --write-media yunyang.mp3
edge-tts --voice zh-CN-YunjiNeural    --text "嗯，慢慢说。我是星回。" --write-media yunji.mp3
# 全部音色：edge-tts --list-voices
```

- 云溪 Yunxi：年轻男声，偏阳光 casual（默认）。
- 云扬 Yunyang：男声，偏新闻播音、沉稳正式。
- 云健 Yunji：年轻男声，偏活泼少年感。

服务端接口：`POST /api/tts/speak`，JSON `{"text": "...", "emotion": "sad"}`，成功返回 `audio/mpeg`；`TTS_ENABLED=false` 时 503，合成失败 502，文本上限 500 字。结果按 音色+参数+文本 哈希缓存在 `runtime/tts_cache/`（已 gitignore）。

实测记录（2026-10-24）：本机源码环境直连微软服务真实合成成功（`TTS_REAL=1` 跑 `test_tts_speak.py` 全过，约 32 秒含网络）；CI 中真实网络用例按设计跳过。
