# MILESTONE_REPORT — 大版本冲刺（发布流水线 / 进化管线 / LLM 总结 / 提醒 / 导出 / 时间线）

日期：2026-10-25 深夜 → 10-26 · 分支 codex/m15 · 模式：无人值守自主连续执行

## 阶段状态表

| 阶段 | 状态 | 说明 |
|---|---|---|
| 0 基线确认 | ✓ | audioplayers 6.7.1 修复推送后 flutter job 全绿（run 40202295550 起 backend+flutter 双绿）；后续每次推送均保持全绿 |
| 1 发布流水线 | ✓ | 代码全部完成并本地提交；push 流水线已加 apk job（debug 签名、14 天 Artifact、xavier-<短sha>.apk、白名单扫描）；release.yml 支持 m15-* 标签→draft Release。干跑 m15-b4-ci 十一轮后端到端验证通过：draft Release 生成，含 m15-b4-patch.zip(4.99MB, SHA256 38781803931405be98c8908e561b1a669c57651f165d9fc2e71cc1e9e66ffcad)+SHA256SUMS.txt，等用户网页核对 Publish |
| 2 人设进化管线 | ✓ | extract_cases.py（单文件输入、零扫描）+ merge_cases.py（--real 全过且零风格回退才追加，冲突只出报告不动 cases.json，v1.5 建议文件不自动生效）+ README 三行反馈指引；端到端演练完成（2 对样例抽取→静态门禁正确拒绝合入），演练输出已贴 |
| 3 每日总结 LLM 化 | ✓ | LLM_DAILY_SUMMARY 默认 false；开+Provider 可用生成 3-5 句第二人称总结（过 style_hits 复核），存 daily_summary（kind 记录，无 SQL 变更→无需 alembic revision，已在提交信息说明）；关/失败/黑名单三路径回退规则版并如实标注，绝不伪造；提示词 docs/prompt.md |
| 4 打卡提醒 | ✓ | 基于 flutter_local_notifications 既有集成（19.5.0，已在 pubspec 锁定且与 3.35.7 兼容——选型依据：项目已在用且 CI 已验证，新增版本无收益）；每日打卡开关默认关、默认 21:00、可改时间、**三版文案 ChoiceChip 供挑选**；权限拒绝显式提示；Android 真机触发【未验证】 |
| 5 聊天导出 | ✓ | JSON/Markdown 双格式走既有 saveFile 流程（Android 走 bytes 保存）；仅对话文本+时间戳，单测断言不含 emotion/turn_id/persona/prompt/token 字段；privacy.md 已补 |
| 6 情绪时间线 | ✓ | 纯 Flutter 柱状图（零新依赖），7 天窗口计数+图例+空态，3 个单测；挂在设置页 |
| 7 终检+本报告 | ✓ | 见下 |

## 测试证据

- 后端：`python -m unittest discover -s tests` **159 个全绿**（skipped=3：真实 edge-tts 网络用例 1 + alembic 在无依赖环境 2）。注：本机 shell 曾发生 PATH 损坏事件，patch_apply 两个用例在损坏 PATH 下会误报（子进程找不到 powershell.exe/chcp）——恢复完整 PATH（System32 + WindowsPowerShell/v1.0）后多次验证 159 OK；CI 干净 runner 从未失败。
- Flutter：analyze/test 由 CI 验证；本批新增 Dart 测试（chat_export/emotion_timeline/tts 修复）已随各提交推送等 CI（见阻塞项）。
- 真实 edge-tts：此前 TTS_REAL=1 实证通过（10-24）。

## 岔路口决策记录

1. **audioplayers 6.8 需 Flutter≥3.44**（CI pub get 失败）：锁定 6.7.1（要求恰为 ≥3.35.0，与 3.35.7 匹配）；用 pub.dev API 核对全部版本约束后精准降版，非盲试。
2. **analyze/test 连续 3 轮失败**：void await（类型修正）、懒加载 AudioPlayer（产品侧正确修法：单测环境无平台通道）、缓存指纹漏 voiceEnabled（内容依赖必须进指纹）、stop 计数（产品语义修正：未播不发云端停止回调）、未用 import。全部修在产品/测试正确性上，未删测试。
3. **Release 流水线 startup_failure ×3**：①workflow_call 未声明 inputs；②可复用作业不支持 continue-on-error；③嵌套发布作业需 contents:write 而调用方只有 read。每次从 API 侧证入手，全部修复，第 4 次起作业正常创建。
4. **draft 下载产物失败**：download-artifact 按当前 run 解析，windows-release 在嵌套子 run——改为 gh api 定位子 run artifact id 后按 octet-stream 端点直取 zip 解包（确定性路径）。
5. **NDK 下载损坏**（apk job 首败）："Archive is not a ZIP archive" 为 runner 侧瞬时网络故障，rerun 即绿，不改代码。
6. **凭据被我误清 + 授权通道故障**：排查时 `git credential reject` 清掉了活凭据（操作失误，如实记录）；随后 GCM 设备码登录连 github.com 直连被重置（.NET TLS 指纹问题，curl 可通而 GCM 不行），且 GCM 走了已死的系统代理。**授权恢复需要你点一次**（见阻塞项）。
7. **音色调整补充**（用户新指令）：TTS_VOICE 改为无预设默认（未设置时接口明确报错），docs/voice.md 保留候选清单仅作参考，UNATTENDED_REPORT 移除音色试听催办——音色导入/切换完全由用户自理。

## 提交清单（本次冲刺，本地共 7 个待推送提交）

- 2cb3bd0 fix: 只在云端实际播放时发停止回调（阶段0）
- 2869730 feat: 标签驱动 draft 发布流水线 + 每日 debug APK（阶段1）
- adc6b83 feat: 人设用例抽取与门禁式追加管线（阶段2）
- b204b11 feat: 可选 LLM 每日总结+诚实回退（阶段3）
- 503ad53 feat: 每日打卡提醒选项与聊天导出（阶段4+5）
- 7519c92 fix: 嵌套 artifact 走 octet-stream 端点（阶段1）
- f268864 feat: 七天情绪时间线（阶段6）
- ff6c2c0 / 316899c：Release 工作流校验修复（阶段1，已推送）

## 遗留扫描

- TODO/FIXME/XXX：后端 0、客户端 lib 0。
- 无死代码改动；无新增无用依赖（阶段4 复用既有插件、阶段6 零依赖）。
- 工作区有 3 个**非本任务产生**的未跟踪项：`config/pet.yaml`、`pet/`、`start_pet.bat`（不是我创建的，按"不动用户文件"红线原样保留，请用户确认来源）。

## 阻塞项（需要用户回来处理）

1. **GitHub 授权**：凭据已被清除（我的失误+授权通道故障叠加）。请在电脑前任意时刻运行 `git push`（或叫我发起），浏览器选 Astra-Logiphos 授权一次即可。
2. **推送与验证**：授权后推送上述 7 个提交 → 等 Test 全绿（含 flutter 对新 Dart 代码的首验）→ 删旧标签重打 `m15-b4-ci` → 盯 Release 到 draft 创建 → 在网页核对后**由你手动 Publish**。
3. **真机/实测**：Android 打卡提醒到点触发【未验证】；气泡朗读/云端音色实测；三版提醒文案挑一版（设置页点选即存）。
4. **m15-b4 干跑结论**：流水线已验证到 windows-patch 全绿 + draft 仅剩产物下载一步（修复已提交）；最终 draft 生成留待阻塞 1-2 解除后一次跑通。

## 需要用户手动做的事汇总

- 点一次浏览器授权（恢复推送）
- push 后盯一次 Actions；核对 m15-b4-ci 草稿并手动 Publish
- Android 真机：打卡提醒、气泡朗读实测
- 设置页：挑一版打卡文案；确认 pet/ 三个未跟踪文件是否为你自己所放
