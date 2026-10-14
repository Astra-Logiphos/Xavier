# 项目维护规则

仅操作当前项目目录。后端只在使用者本地 Windows 运行，不提出远程服务器方案。保留已有内容与工作流。禁止提交真实聊天、数据库、权重、缓存、私钥和 API Key。
默认 API/付费/搜索/Ollama/语音真实服务关闭。所有外部来源先审核；canon 不由聊天修改。
业务通过 LLMProvider 调用模型；模型名与 Key 来自服务端环境变量。客户端不含模型 Key。
修改正式人设必须生成版本、差异摘要与 persona_eval_report.md，门禁通过才 active。
验证：`python -m unittest discover -s tests -v`；Flutter `flutter analyze && flutter test`；真实构建仅 GitHub 托管 runner。
没有证据不得声称外部 API、Flutter 构建或 Release 发布成功。单用户 SQLite 原型不得伪称生产多用户系统。

【交付与补丁规则】
1. 交付采用"底座+补丁"制：用户本地保留一份完整安装（底座），每次验收只发增量补丁包，禁止再发整包（重建底座除外）
2. 补丁包命名 m{模块}-b{批次}-patch.zip，内含：
   - manifest.json：批次号、基于的底座版本（git 短 hash）、变更文件清单（相对路径+大小+文件数）
   - 变更文件本体（保持安装目录相对路径）
   - apply_patch.bat：运行前检测 App 是否在运行（在运行则提示先关闭）→ 把被替换文件备份到 backup/{批次号}/ → 覆盖 → 按清单校验文件数与大小，不一致则中止并提示 → 打印"补丁已应用，版本 {批次号}"；同时生成 revert.bat 可回退本批
3. 变更清单用 git diff --name-only 生成，宁多勿漏；DLL/运行时文件无变化不得打包
4. 用户自管理内容永不打包：assets/voices/（语音包）、数据库文件、backup/
5. App 设置页显示版本戳（模块·批次·git 短 hash），用户据此确认补丁已生效
6. 每份验收报告必含补丁体积；预期：纯后端/配置/prompt 变更 <1MB，含前端 Dart 变更约 5-20MB，超过 20MB 必须说明原因
7. 底座丢失或补丁链出错时，重建整包重置底座（仅此情况发整包）
