# 模块十五批次四：多模型供应商验收报告

## 方案摘要

五家供应商共用现有OpenAI兼容LLMProvider，不新增依赖或架构。预填地址、模型与免费分类集中在config/model_providers.json；实际供应商、地址、模型、Key仍唯一读取服务端环境变量。新增标准库Windows注册表环境变量读写：向导写入当前Windows用户的永久环境变量，并由新后端进程主动重读，避免监督程序继承旧环境。每家独立Key引用，切换不删其他Key；客户端只临时输入并通过带AUTH_TOKEN的127.0.0.1发送，保存/离开即清空，不进入SharedPreferences、数据库或导出。

免费预设仅对匹配官方地址及精确模型名放行费用门禁；自定义地址/其他模型要求明确费用确认，不自动保证平台额度。API仍默认关闭，用户明确启用；现有每轮REQUIRE_API_CONFIRMATION选择保留到批次三D1统一处理。

模型测试网络I/O不持有Store锁；聊天在短临界区冻结本轮供应商配置后调用，切换平台不会把正在返回的旧请求标作新平台。今天用量显示调用数及供应商返回的输入/输出token，最近错误已脱敏，401/402/404/429/网络失败按平台给中文提示；火山404提示控制台开通及接入点ID。

主题、背景、气泡、记忆与人格组装不改。人格v1.1草稿已获用户批准，本批仍不注入，批次三第二段将统一正式版本/门禁/页面来源。独立预览测试脚本只读取用户本机Key，无Key时blocked，三轮真实回复尚未获得，不用mock冒充。

## 改动文件列表

- `.github/workflows/build-windows.yml`
- `client/flutter_app/lib/main.dart`
- `client/flutter_app/lib/model_panel.dart`
- `client/flutter_app/test/model_panel_test.dart`
- `config/model_providers.json`
- `docs/module-15-b2a-acceptance.md`
- `docs/module-15-b4-acceptance.md`
- `docs/persona/fewshot_examples.md`
- `docs/persona/fewshot_v1_1.diff`
- `docs/persona/prompt_candidate_v1_1.txt`
- `docs/persona/prompt_optimization_proposal.md`
- `docs/persona/prompt_preview_v1_1.diff`
- `docs/persona/xavier_card_v1_1.md`
- `scripts/build_patch.py`
- `scripts/bundle_windows_backend.py`
- `scripts/probe_persona_draft.py`
- `scripts/smoke_model_wizard.py`
- `scripts/smoke_patch_bundle.py`
- `server/api/app.py`
- `server/model_config.py`
- `server/model_environment.py`
- `server/model_service.py`
- `server/providers/__init__.py`
- `server/providers/base.py`
- `server/providers/cloud.py`
- `tests/test_model_environment.py`
- `tests/test_model_wizard.py`
- `tools/pack/patch.ps1`

## 前后数据对比

|项|m15-b2a|本批|
|---|---|---|
|供应商工厂|智谱/DeepSeek|智谱、硅基流动、火山、百炼、DeepSeek|
|配置入口|手动Windows环境变量|设置页本机向导，独立平台Key永久保存|
|模型错误|通用提示|平台名+401/402/404/429/网络原因，隐藏响应正文|
|当前用量|未展示|今日调用数/输入输出token/最近错误|
|回退|代码与版本|同时恢复非秘密环境选择，Key和用户资产保留|
|人格、主题与记忆|原行为|不改，v1.1第二段另批落地|

## 测试结果

本机后端111项执行：106通过、5项Windows专属跳过。新增五供应商请求契约、费用门禁、错误Key与错误码、旧Key保留、导出无Key、注册表持久化及失败事务回退。Flutter analyze零问题、43项Flutter测试通过；Windows发布编译、原生注册表保存/重启/旧Key保留和实际补丁应用/独立回退均须通过后发布，最终结果见Release更新。

智谱真实Key全流程：待用户自测；其余四家：结构验证，未实测外部API。错误Key分类由真实HTTPError契约+原生Windows模拟传输验证，不宣称已访问平台。当前工作区无Key，三轮v1.1语义实测做不到，安装后可运行独立测试入口。

## 补丁、体积与应用

前置必须为m15-b2a · f7e33b4，原始底座666e2e2。后续m15-b3以前置m15-b4制作；按用户新T3改变交付顺序，manifest按实际链记录。分支codex/m15，独立tag m15-b4。

关闭App与本地后端→解压m15-b4-patch.zip→运行本补丁apply_patch.bat并输入安装目录→start_all.bat；在设置页检查m15-b4版本戳。回退时关闭两者运行本批revert.bat；若已经安装后续批，须先回退后续批。代码、版本与非秘密模型选择恢复，Key不进备份、不被删除。

做不到纯后端<1MB的预期：本批规格要求新增设置向导，必须交付Dart编译快照。最终字节数、SHA256及源版本将在Windows构建发布后补齐。不发送整包，不打包语音、桌宠、config/avatars、数据库或backup。无原生依赖变化时复用底座DLL，避免编译时间戳造成无必要DLL补丁。

## 用户事后验收

1. 设置→模型配置向导→选智谱：地址自动预填；粘Key，测试连接，选glm-4-flash（改变模型后重测），启用模型调用，保存；Key输入框清空。
2. start_all重开：平台/模型与Key配置状态保留；完成真实智谱一轮。免费模式保留你的REQUIRE_API_CONFIRMATION=false；收费模型必须勾选明确费用确认。
3. 填错误Key点测试，显示智谱401等中文错误；设置状态有最近错误与调用数，错误内容没有Key。错误Key测试不覆盖已经保存的好Key。
4. 切其他平台查看预填与模型，火山显示需开通模型；没真实Key只验证结构，不能称API已测。切回智谱留空Key，后端原Key仍在。
5. 重启后端及Windows确认永久配置；如已有同名系统变量，向导保存的用户变量优先。Key只在环境变量，不在App或补丁。
6. 运行本批revert，版本与原模型选择恢复；用户头像、数据库、语音与模型Key保留。

## 人格草稿与后续

已批准八轮和候选prompt，但本批不激活。候选差异docs/persona/prompt_preview_v1_1.diff，说明与D1—D4队列docs/persona/prompt_optimization_proposal.md。本机三轮独立入口：在安装目录backend运行 `python\python.exe -B -X utf8 -m scripts.probe_persona_draft --approve-test-api --output ..\persona-v1_1-probe.json`，使用既有智谱环境变量，不读取真实聊天、不激活版本。没Key返回blocked、0轮。

现有UI-01图库缩略装饰越界列入批次三修复；真实朗读仍为已接受的模拟限制，SAPI后议。

## 最终交付核验

Windows流水线38570355854全部通过：111项后端（0跳过）、43项Flutter、analyze零问题、发布编译、原生五家配置持久化/进程重启/旧Key保留/401分类/用量/导出无Key、头像与一键启动、补丁应用及独立回退与非秘密环境恢复。外部模型传输为mock，真实API仍按前述待用户实测。

源码/设置版本：m15-b4 ·3ef91c5；补丁4379934字节，20个载荷文件。SHA256：`1be52f62b50b20ddc326561be962dbd3a32aefd138107d052df46b081366ba38`。

[下载补丁](https://github.com/Astra-Logiphos/Xavier/releases/download/m15-b4/m15-b4-patch.zip)。本机下载副本逐项大小与SHA验证通过，未打包未变DLL。发布包内报告为构建前指南，本文与Release正文补齐最终证据，tag保持3ef91c5不变。
