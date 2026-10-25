# 发布流水线（m15 批次）

## 以后发版只需一行

```bash
git tag m15-b3a && git push origin m15-b3a
```

推上 `m15-*` 标签后自动执行：后端全量测试 → Windows 增量补丁（串联既有补丁链、构建、冒烟）→（配置了签名 secrets 时）Android release APK → 白名单扫描 + SHA256SUMS → **创建 DRAFT Release**。草稿不会自动发布，核对后你在网页端手动点 Publish。

- 支持的批次：m15-b2 / b2a / b3 / b3a / b4。
- 干跑验证约定：标签加 `-ci` 后缀（如 `m15-b4-ci`）→ 按对应批次构建，产物仍只进草稿。
- 未配置 Android 签名 secrets（当前仓库即此状态）时，android 作业明败，草稿仅含 `*-patch.zip + SHA256SUMS.txt` 并在说明中标注缺 APK；不伪造签名包。

## push 日常流水线

push 到任意分支即跑：后端 unittest + flutter analyze/test + **debug APK**（14 天 Artifact，命名 `xavier-<短sha>.apk`；无签名密钥环境用 debug 签名，可安装实测）。release 签名 APK 仅出现在标签流水线。

## 资产白名单

`scripts/check_release_assets.py` 在发布前强制扫描：扩展名仅 apk/zip/txt；文件名与 zip 内路径禁 `.env/.db/.sqlite/.jsonl/聊天记录`；文本与 zip 条目内容扫描 `ghp_ / github_pat_ / sk-` 凭据模式。命中即构建失败。

## 配置签名（补 APK 用）

仓库 Settings → Secrets and variables → Actions 添加：`ANDROID_KEYSTORE_BASE64 / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD`。补齐后标签流水线自动带上 release APK 与 AAB（AAB 因扩展名不在白名单仅留 Artifact，不入草稿）。
