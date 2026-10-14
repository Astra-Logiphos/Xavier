# 本地问候语音包

设置开启“语音包问候”后，主动问候/关怀/休息事件会尝试播放用户自备WAV；聊天消息菜单朗读仍为此前已接受的模拟，不是新增TTS。

将录音放在安装目录 assets/voices/ 下对应子目录，目录内任意 .wav 文件可自动识别：greeting_morning、greeting_afternoon、greeting_evening、greeting_night、care、rest。无需安装播放器或新增依赖；Windows用内置SoundPlayer，找不到素材则只显示台词，不阻塞聊天。

如已有其他目录划分，可自管理 assets/voices/manifest.json，把上述场景映射为相对路径数组。例如 greeting_morning 对应 ["问候/早安.wav"]。不接受网络URL、目录越界或外部绝对路径。当前驱动支持WAV；不能把未提供的素材或未实测的声音效果称为通过。

assets/voices 始终由用户管理，不进入补丁、回退或构建产物。参考目录 docs/refs/voice/ 空置不阻塞，提供参考清单后再调整触发场景。此次仅验证缺素材和非法路径处理；实际录音及声音输出待用户自测。
