# 云端部署与构建

## 后端

Python 3.12+。复制 .env.example 字段到部署平台环境变量，不把 .env 上传 GitHub。程序不自动读取 .env。
设置随机且至少 32 字符 AUTH_TOKEN，HOST=0.0.0.0，PORT=8080，DATABASE_PATH=/app/runtime/xinghui.db。环境变量已设置后 `python -m server.api.app` 即可；Docker 模板使用非 root 用户。
给 runtime 挂持久卷，容器 UID=10001 需写权限；迁移启动时自动执行，绝不把真实数据库入库。关闭 request/body 日志与外部错误收集原文。平台提供 HTTPS 和限流；wsgiref 只是原型服务器，不直接公网暴露。
客户端设置 https://your-api-domain 与 AUTH_TOKEN，令牌使用平台 secure storage，模型 Key 不进客户端。
没有 token：health 可用但个人接口返回 503；没有 Key：mock 可用，选真实供应商时提示未配置。

## 模型配置

默认 ACTIVE_PROVIDER=mock，API_ENABLED=false，REQUIRE_API_CONFIRMATION=true，ALLOW_PAID_API=false。
DeepSeek：DEEPSEEK_API_KEY + DEEPSEEK_MODEL；智谱：ZHIPU_API_KEY + ZHIPU_MODEL。模型名按官方当前文档在部署平台填写，业务不硬编码。
显式启用真实模型还需 API_ENABLED=true；由于免费配额未验证，真实调用要求 ALLOW_PAID_API=true，并在客户端确认本轮 API。这可能产生费用，不能当免费模式。MAX_DAILY_MODEL_CALLS 限制次数，另设供应商金额预算。
Ollama 只预留，不接用户电脑；语音真实服务未接入。客户端语言设置预留 en-US/ja-JP，真实多语识别合成待验证。

## Flutter

GitHub runner 使用 Flutter 3.35.7 / Java 17。脚本生成 Android/Windows SDK runner，在生成目录内配置 Android 网络权限、禁明文、release 签名。修改脚本前确认 SDK 模板，模板不匹配就失败，不静默退回 debug 签名。

```
python scripts/bootstrap_flutter.py
cd client/flutter_app
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

生成的原生 runner 可在固定 SDK 后纳入未来仓库版本，但不得提交临时凭据。依赖尚无 pubspec.lock；首次成功 CI 后提交锁文件并固定 Actions commit SHA。此交付仍不能称完全可复现构建。

## Android 签名

在 GitHub 云端开发环境使用 JDK keytool 生成专用于应用的密钥，输出放 runtime（gitignored）；不要把密钥命令中的密码写到终端历史或日志。记录并安全备份，否则更新签名不可恢复。

```bash
mkdir -p runtime
keytool -genkeypair -keystore runtime/release.jks -alias xinghui -keyalg RSA -keysize 2048 -validity 10000
```

按交互提示填写。将文件的 Base64 作为 ANDROID_KEYSTORE_BASE64，另外设置 ANDROID_KEYSTORE_PASSWORD、ANDROID_KEY_ALIAS、ANDROID_KEY_PASSWORD 四个 Repository Actions Secrets。不要在本对话粘贴或提交这些值。GitHub 界面 Settings → Secrets and variables → Actions → New repository secret。生成和注入是用户在自己的云端环境操作，不要求本任务访问本地电脑。
Android Workflow 没有四个 Secrets 就失败，避免假正式包。输出 APK / AAB。Windows ZIP 未签名，安装包预留脚本说明，见 scripts/windows-installer.md。

## Actions / Release

Test 在 push/PR 运行；PR 还验证 Android debug 编译与 Windows release ZIP，不把开发 APK 当正式发布。Build Android/Windows 可手动 Run workflow；Release 在 v* tag 运行并复用构建流程。release publish 权限仅单个 job contents:write，使用临时 GITHUB_TOKEN，不需 PAT；只 GitHub 托管 runner。
Android 和 Windows 都成功且后端门禁通过后 gh release create 上传明确文件白名单与校验和；不会将仓库/runtime 一起打包。
来源说明：Flutter 官方 [Android 部署](https://docs.flutter.dev/deployment/android)、[Windows 部署](https://docs.flutter.dev/deployment/windows)、[持续交付](https://docs.flutter.dev/deployment/cd)；[DeepSeek](https://api-docs.deepseek.com/api/create-chat-completion/)、[智谱](https://docs.bigmodel.cn/)。
官方文档已检索；SDK、模型 API 和工作流未实跑验证，不以文档浏览替代构建验证。
