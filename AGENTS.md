# 项目维护规则

仅操作云端项目目录。保留已有内容与工作流。禁止提交真实聊天、数据库、权重、缓存、私钥和 API Key。
默认 API/付费/搜索/Ollama/语音真实服务关闭。所有外部来源先审核；canon 不由聊天修改。
业务通过 LLMProvider 调用模型；模型名与 Key 来自服务端环境变量。客户端不含模型 Key。
修改正式人设必须生成版本、差异摘要与 persona_eval_report.md，门禁通过才 active。
验证：`python -m unittest discover -s tests -v`；Flutter `flutter analyze && flutter test`；真实构建仅 GitHub 托管 runner。
没有证据不得声称外部 API、Flutter 构建或 Release 发布成功。单用户 SQLite 原型不得伪称生产多用户系统。
