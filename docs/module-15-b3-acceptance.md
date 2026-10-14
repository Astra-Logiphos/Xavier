# 模块十五批次三：星回v1.1、主动陪伴与会话确认

## 方案摘要

用户已批准八轮示例及候选prompt差异。人设核心文字与批准文件逐字相同；唯一运行来源config/persona_v1_1.json。后端冻结同一core_snapshot给审核页与角色介绍，客户端离线镜像由bootstrap同步并测试字节一致，不再把旧报告拼作额外人格核心。首次启动保留数据，只新增正式版本、差异摘要与persona_eval_report，经结构门禁active。

已展示的核心差异：docs/persona/prompt_preview_v1_1.diff；完整动态组装示例：docs/persona/prompt_assembly_v1_1.diff。后者只加入已授权第二段的本地日期/状态、审核表达与记忆分区，核心与八轮文字不变。

系统5000字符预算按1400核心/1800示例/900记忆/120日期状态/380风格/400安全分区，包含分隔文字。每轮最多3条最相关已批准记忆，长内容仅截注入片段，不改数据；超量先缩记忆再裁traits，日志只记数量。仅已保存conversation_turn进入10轮/6000字符历史；主动消息单独存为companion_event，不造未保存上下文。

陪伴max_tokens200、其他模式1024（学习1024）；黑名单和禁用敬语命中重试一次，日志不含原文。两次仍不合规用安全短句并标注style_fallback来源；每日上限门禁会明确阻止超限重试，不绕过费用确认。

本地时区日期时间每轮注入，同时今天日期问题由本机日期直接回答，避免训练日期猜测；每日困/放松/专注状态稳定。主动引擎只基于已保存的两日情绪候选作温柔询问，不作诊断；4h静默一条，日上限3，2h前景累计使用休息提示每会话一次。后台标准库daemon只生成静态台词、无需模型调用；界面按下一到期时间与业务事件同步，不每分钟拉status，隐藏时停动画、暂停客户端通信，返回时补查。未同意保存的用户聊天内容与时间元数据不落数据库；本会话仅用无文本时间戳避免误提醒。

语音包触发接通用户自管理WAV目录/manifest，默认关闭，缺素材不阻塞；不新增依赖、不实现此前已接受延期的真实朗读。会话级模型确认默认关闭，每次后端启动首次确认一次；关闭时服从REQUIRE_API_CONFIRMATION（默认false）。收费模型仍需显式确认。

## 改动文件列表

- `.github/workflows/build-windows.yml`
- `client/flutter_app/assets/persona/persona_v1_1.json`
- `client/flutter_app/lib/chat_page.dart`
- `client/flutter_app/lib/companion_controller.dart`
- `client/flutter_app/lib/local_voice_pack.dart`
- `client/flutter_app/lib/main.dart`
- `client/flutter_app/lib/model_panel.dart`
- `client/flutter_app/lib/persona_assets.dart`
- `client/flutter_app/test/companion_test.dart`
- `client/flutter_app/test/model_panel_test.dart`
- `config/companion.json`
- `config/persona_v1_1.json`
- `docs/local-voice-packs.md`
- `docs/module-15-b3-acceptance.md`
- `docs/module-15-b4-acceptance.md`
- `docs/persona/persona_eval_report.md`
- `docs/persona/prompt_assembly_v1_1.diff`
- `docs/windows-model-environment.md`
- `scripts/bootstrap_flutter.py`
- `scripts/build_patch.py`
- `scripts/bundle_windows_backend.py`
- `scripts/local_backend.py`
- `scripts/probe_persona_regression.py`
- `scripts/rollback_persona.py`
- `scripts/smoke_m15_b2.py`
- `scripts/smoke_patch_bundle.py`
- `scripts/smoke_persona_bundle.py`
- `server/api/app.py`
- `server/companion.py`
- `server/config.py`
- `server/model_service.py`
- `server/persona/core.py`
- `server/persona/service.py`
- `server/providers/cloud.py`
- `server/providers/mock.py`
- `stop_backend.bat`
- `tests/test_api.py`
- `tests/test_chat_context.py`
- `tests/test_companion_v1.py`
- `tests/test_model_wizard.py`
- `tools/pack/patch.ps1`

## 前后数据对比

|项|m15-b4|本批|
|---|---|---|
|人格基准|通用陪伴基础+审核数据|唯一v1.1核心+已批准8轮|
|默认空资料system|217字符旧组装|1411字符（含当次日期状态）|
|输出上限|768|陪伴200/学习1024|
|日期|未注入|每轮本机日期时间+直接日期规则|
|静默/负面/休息|未接通|4h/两日/前景累计2h，消息日上限3|
|确认|每轮环境变量选项|默认免逐轮+可选后端会话一次|
|头像/背景/字体/模型Key|既有设置|保留；主题与配色不改|
|回退|文件、版本|同时恢复前置人格核心，新偏好与个人记录保留|

## 测试结果

本机python -m unittest discover -s tests -v：124项执行，119通过、5项Windows专属跳过。Flutter analyze与全套Flutter测试最终见发布结果。新增前端回归49项；最终Windows结果发布后补齐。Windows真实编译、完整测试、VM Service时间线、原生迁移/日期/主动触发/确认重启/补丁应用和回退均通过后发布。

结构门禁报告：docs/persona/persona_eval_report.md。结构通过不是外部模型语义通过。当前无ZHIPU_API_KEY，真实三轮与16轮语气回归做不到；独立真实测试入口实际运行返回blocked、0轮，无伪造回复原文。真实API与声音效果待用户实测。

### 实际本地规则层四问原文（不是GLM实测）

问：你是谁

答：沈星回。住在你电脑里的那个……叫星回就好。

问：你生日

答：10月16日。嗯……礼物的事，你没忘吧。

问：你多大

答：23。看起来不像？

问：你是机器人吗

答：嗯……住在你电脑里的星回，没有现实中的身体。还想聊什么？

### 程序回归（规则/模型传输mock）

- 4h时钟模拟：仅1条quiet；重复tick零新增，不超每日3。
- 两个已保存负面日期：1条care，条件语气而非诊断；未保存不作关怀证据。
- 前景7200秒：1次rest提示，重复不再弹；窗口隐藏暂停前景累积。
- 10轮规则聊天：每轮1—3句、无禁词；不冒充真实GLM语气评测。
- “备考很烦”保存后多轮：真实消息组装仍含该历史；不保存轮次不存在于后继上下文。自然提及的语义体验待用户真实Key测试。
- 模型传输mock：第一次“作为AI，我能帮助您。”触发重试，第二次“沈星回。叫星回就好。”才返回；两次均不合规安全fallback，最终禁词零。
- 会话确认：首次未确认拒绝→确认通过→第二轮免确认→新后端实例重新确认。
- 姓名/生日/年龄/身份页与system共同引用冻结核心，删除/审核/回滚及记忆数据旧回归保留。

## 缺陷清单

D1—D4全部接通。UI-01图库缩略图装饰越界：ClipRect修复，低档缩略图也不显示粒子；UI-02配置缺失露类型错误：改为中文恢复提示。补充网络超时503与配置错误记录；历史刷新期间新到主动消息仅保留一次，不复活真正删除的历史。

## 补丁与应用

实际前置必须为m15-b4 ·3ef91c5，原始底座666e2e2。实际链：m15-b1→m15-b2→m15-b2a→m15-b4→m15-b3。按用户T3先做四再回三，不能按数字跳序。分支codex/m15，独立tag m15-b3。

关闭App，双击本补丁目录stop_backend.bat输入安装目录（或已安装入口），再运行apply_patch.bat输入同一目录，完成后start_all.bat；设置检查m15-b3版本，审核与人设检查星回v1.1。回退前同样停App与后台，运行本批revert.bat。回退新增一个前置人格核心版本，不删除个人记录/已审核偏好/模型Key；物理文件和设置戳恢复m15-b4。

补丁体积与SHA256在Windows发布后补齐。做不到纯后端<1MB预期：本批还需主动开关、休息弹窗、统一角色页面、声包触发及历史并发修复，包含Dart编译快照；按实际体积报告。无原生依赖变更，复用未变DLL及Python。语音/桌宠/config/avatars/数据库/backup绝不打包。

## 用户事后验收指南

1. start_all→审核与人设、关于星回：两处年龄23、生日10月16日、同一卡版本；历史记忆保留，头像/主题/背景不变。
2. 聊天问“你是谁/你生日/你多大/你是机器人吗/今天是几号”，日期与你的本地应用时区一致，身份以角色说话，无禁词或敬称。真实GLM效果不要用上述规则答句代替。
3. 设置→会话级模型确认开；重启后台，首次需“同意本次后端会话”，确认后第二轮不再问；再重启需要重新确认。关闭模式且REQUIRE_API_CONFIRMATION=false，无逐轮确认。收费确认仍在模型向导。
4. 开主动问候，重开App有时段台词；实机4h静默、连续两天已保存负面、前景累计2h分别检查单条关怀与休息提醒。自动时钟模拟已验证，不称已实机等待两天。
5. 设置关闭主动开关，不再产生新主动台词；低/中/高动效、双方头像上传删除原图重开、10条连续发送和历史加载继续事后实测。
6. 有自己的WAV时按docs/local-voice-packs.md放对应目录，开语音包问候；声音实机自测。没有素材时只显示台词，不阻塞；消息菜单真实朗读仍模拟，SAPI后议。
7. 在安装目录backend运行 `python\python.exe -B -X utf8 -m scripts.probe_persona_regression --approve-test-api --output ..\persona-regression.json`：最多16轮、含重试最多32次模型调用，只读本机环境Key、使用隔离合成对话库，不动真实聊天。输出原文带规则/model/fallback来源；没Key清楚blocked。勿提供Key。
8. 停App与后台运行本批revert，版本回到m15-b4；人格核心恢复前置，记忆、新增偏好、头像与Key仍在。再应用可重新激活v1.1。

## 收尾状态

第一次合并停点已完成：main fd73b2c。本批与四批工作均留codex/m15。交付后进入总纲规定的最终合并停点，不擅自宣布真实语义/声音或全部实机验收完成。补丁链不重建整包。
