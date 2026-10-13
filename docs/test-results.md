# 验证结果 / 2026-10-13

- Python 3.12：48 项离线单元、WSGI 集成与策略回归测试通过（合成样例、内存数据库）。
- 覆盖模型安全门禁、人设分层/审核/回滚、隐私命令、候选记忆审批/删除/过期/冲突、重复反馈风格候选、相关性检索、学习复习、打卡与每日结构化候选。
- GitHub Test 已实际通过 Flutter analyze 与 flutter test；新增逐字段表单 widget 测试亦通过（0856730 commit）。
- Android debug APK 已成功构建（run 38344102731）。首个预览 APK 产出但 Release HTTP 403；第二个预览已成功发布 android-preview-2-1。不是生产签名版。
- Windows release ZIP 构建和打包已通过（runs 38344284638、38344551244）。新版本已加入常用表单、可再分发 CRT 检查与云端 10 秒启动 smoke；最新结果以对应 Actions 为准。
- 数据 JSON、Python AST、workflow YAML 静态检查通过；这些不替代实际平台构建。
- 人设策略门禁初始 persona-0001 通过；真实模型语义/语气漂移未验证。
- DeepSeek/Zhipu 仅模拟契约；小红书/Bilibili/PublicWeb 外部连接未授权；语音只有 mock；无用户真机 UI 验收、Windows 代码签名或正式 Android 签名。

不把离线测试、静态 YAML、任务排队或模拟接口当真实连接与模型学习成功。

最终桌面验证：Windows build/run 38345926546 全部成功（编译、Flutter analyze/test、CRT、10 秒启动与打包/上传）。Windows Release windows-preview-8-1 已发布。源代码 PR #1 已合并 main（merge commit 3795ee3569a295950c6049d990a81fb4717faca7）。这些证据不等于用户设备 UI 验收。


## 2026-10-13 系统改造

第一批Windows运行38394163472成功：56项后端、12项Flutter及analyze/编译/打包检查。第二批Windows运行38402112771成功：59项后端、19项Flutter及analyze/编译/打包检查。第三批初次源码850ef32与最终数据修订待Windows构建结果；本机62项后端（61通过、1 Windows专属跳过）、22项Flutter和analyze检查。实际Windows通知横幅、Android完整构建、用户设备视觉验收不由本机模拟结果替代。

食品新版来源保留七字段1838条，226条未知或超界能量置空；测试检查全部非空energyKCal在0–1000内。运动镜像1111条保留代码/描述/MET/22类别，不称完整1144条。饮食/运动双Tab实操测试按150克和70kg慢跑30分钟验证262.5千卡消耗，并核对净值。
