# 模块14.5批次一验收报告

分支 codex/m145；补丁代码版本 b2a570f，底座666e2e2。自动验收通过；用户已确认补丁安装及版本戳m145-b1 · b2a570f，并授权合并。真实智谱三轮自测由用户暂缓，随外观批次继续。本报告为最终版；补丁内文档为构建时操作指南，最终实测证据以本报告及Release说明为准。

## 最终方案

ThreadingMixIn + WSGIServer、daemon_threads=True；聊天锁内准备→锁外模型调用→锁内保存，其他请求的复合操作锁及Store内部RLock保留。审核/发布/回滚/恢复/摘要/候选提取保持一致；清空/恢复增加数据代次，旧请求不写回，保存前复查开关。

config/chat.json（安装位置backend/config/chat.json）默认10轮/6000字符：标准库JSON无需依赖、绝对定位不依赖工作目录。只使用已保存且consent=true的完整conversation_turn，超预算从最旧整轮移除，未保存轮次不补入，system组成不变。

model_config.py统一读取供应商/base_url/模型/Key引用，注册结构预留扩展；本批智谱glm-4-flash，保留既有DeepSeek适配器。地址及模型无代码默认值，Key不入客户端/日志/补丁；真实API默认关闭。

## 底座与应用入口

本入口仅适用于666e2e2纯净底座：b0已回退、install-state.json的patch_id=null；保留backup/m145-b0不影响应用。

1. 关闭App及本地后端，包括监督程序/自启实例。
2. 单独解压m145-b1-patch.zip；双击补丁目录根部apply_patch.bat，输入现有底座目录。不要把ZIP直接覆盖到底座。
3. 预期“补丁已应用，版本m145-b1”；重开App→设置，版本戳为m145-b1 · b2a570f。
4. 双击底座start_backend.bat→App设置连接本地后端；发消息并重开，确认聊天保存正常。
5. 回退：关闭App/后端，运行底座根部revert.bat指向同目录，版本恢复m145-base · 666e2e2，原文件恢复、新增文件移除，backup/m145-b1保留。

b0未回退会拒绝应用。本批不包含主题/背景/前端/DLL/便携Python，也不包含数据库、语音、桌宠素材和backup。

## Windows智谱环境变量设置

backend/.env.example仅作说明、不自动加载。先关闭已有后端，在一个Windows PowerShell窗口执行以下设置；Key隐藏输入，不写命令历史：

```powershell
$env:ACTIVE_PROVIDER='zhipu'
$env:ZHIPU_BASE_URL='https://open.bigmodel.cn/api/paas/v4'
$env:ZHIPU_MODEL='glm-4-flash'
$secret=Read-Host '智谱 Key' -AsSecureString
$credential=[System.Net.NetworkCredential]::new('', $secret)
$env:ZHIPU_API_KEY=$credential.Password
$env:API_ENABLED='true'
$env:REQUIRE_API_CONFIRMATION='true'
$env:ALLOW_PAID_API='true'
& '你的底座安装目录\start_backend.bat'
```

ALLOW_PAID_API=true为显式允许可能产生费用的调用，本批保留费用门禁，不保证供应商免费额度。上述变量仅本窗口及其子进程有效；关闭窗口后不持久化。开机自启需另设本机用户环境变量并重启后端，Key不要放入项目文件。

App→设置连接后端，开启保存聊天；聊天使用现有“本轮API确认”入口。依次发送：“我今天在复习线性代数”“我明天还想继续这个主题”“我刚才说在复习什么？”，检查第三轮正确引用前文。真实三轮对话：**待用户自测**（工作区无Key）。

## 前后数据对比与测试结果

| 项目 | 之前 | 之后 |
|---|---|---|
| 服务器/模型等待 | 单线程＋整请求锁 | 多线程，模型等待不持数据库锁 |
| 历史 | 0轮 | 最多10轮、6000字符；只取已保存整轮 |
| 地址/模型/Key | 地址硬编码、配置分散 | model_config统一读服务端环境变量 |
| 慢模型期间/status | Linux控制模型300ms后释放，耗时301.507ms | Linux复用客户端平均1.077ms、最慢1.390ms；Windows平均1.173ms、最慢1.213ms |
| 后端单测 | 69项 | 87项（新增18项） |

测试命令：python -m unittest discover -s tests -v。
- 本机：87项，82通过、5项Windows专属跳过，0失败，2.817秒。
- Windows：87项全部通过，0跳过，14.048秒。
- Flutter analyze：本机及Windows均零问题；flutter test：本机及Windows均24项通过。
- 并发：慢mock LLM未返回期间，Windows连续5次/status为1.2051、1.1483、1.2040、1.0945、1.2126ms，全部<100ms。计时复用HTTP客户端，不含初始化/Windows证书库加载。
- 数据一致性：模型等待时清空/恢复禁止旧请求写回、关闭保存开关不保存；审核与发布对状态读取保持一致，测试通过。
- 历史：空集、恰好N轮、整轮超预算裁剪、顺序、未保存/未同意/缺失轮次、三轮以上mock上下文组装通过；system组成保持原样。
- 模型配置：正常、缺Key/模型/地址、无效地址、供应商隔离及既有适配器契约通过。
- 真实Windows：App运行时拒绝补丁；应用/备份/版本更新；便携后端BAT、令牌复用、聊天与记忆保存、崩溃重启、自启注册；回退恢复原文件、移除新增文件及恢复底座版本，全部通过。
- 下载后检查SHA256、清单文件数/大小/逐文件哈希、用户资产及DLL/运行时排除：通过。
- Windows检查：https://github.com/Astra-Logiphos/Xavier/actions/runs/38519639226
- 真实智谱三轮对话：**待用户自测**，无可用Key，未声称真实模型已验证。

## 补丁交付与体积

m145-b1-patch.zip：**26,262字节（约25.65KiB），小于1MB**；11个载荷文件；manifest基于666e2e2，previous_patch=null，版本b2a570f。本入口针对b0已回退的纯净底座；无需重新下载底座。

下载：https://github.com/Astra-Logiphos/Xavier/releases/download/m145-b1-preview-39-1/m145-b1-patch.zip

SHA256：08c13d78507e434c29e64e5bad4128d34efdbbe765a89841187c6887ce196b20。

应用一句话：关闭App及本地后端→独立解压补丁→运行补丁根部apply_patch.bat输入现有底座目录→重启查看设置版本m145-b1 · b2a570f。

原始证据：https://github.com/Astra-Logiphos/Xavier/releases/tag/m145-b1-preview-39-1 （backend-tests.txt、patch-smoke.txt、SHA256SUMS.txt）。

## 改动文件清单

- server/api/app.py
- server/memory/store.py
- server/memory/context.py
- config/chat.json
- server/config.py
- server/model_config.py
- server/providers/__init__.py
- server/providers/cloud.py
- server/providers/ollama.py
- .env.example
- tests/test_api.py
- tests/test_concurrency.py
- tests/test_chat_context.py
- tests/test_model_config.py
- tests/test_patch_packaging.py
- scripts/build_patch.py
- scripts/bundle_windows_backend.py
- scripts/smoke_patch_bundle.py
- .github/workflows/build-backend-patch.yml
- .github/workflows/build-windows.yml（补丁工作流入口）
- docs/module-145-b1-acceptance.md

已记录：后续开放轮数/预算调整时入口放设置页，避免手改文件被补丁覆盖；本批不实现该入口。
