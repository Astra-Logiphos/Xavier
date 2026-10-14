# 聊天气泡参考

开工检查时 docs/refs/chat-bubble、cute-ui、pet 均无参考图片或 README。采用 AGENTS.md 的默认规格：对齐左右分边、外侧40px头像、5分钟时间分组与70%宽度；保留圆润20px、圆形头像、轻微阴影、主题主色派生气泡。

不采用微信绿色气泡、灰色页面背景、方形头像；不改动 theme.yaml 的颜色和背景。参考图片到位后，以参考为准。

config/bubbles.yaml 为唯一编辑入口，使用与 theme.yaml 相同的 YAML 1.2 JSON 记法。client/flutter_app/config/bubbles.yaml 是随构建同步的默认资源；Windows 优先读取安装目录 config/bubbles.yaml，编辑后重启生效。avatar.userPath仍支持安装目录相对路径或本机绝对路径。设置→我的头像上传会优先使用安装目录config/avatars/内的压缩副本，不记录原图路径；恢复默认后重新使用avatar.userPath。用户头像不进入补丁包。
