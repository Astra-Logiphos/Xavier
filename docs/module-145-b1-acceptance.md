# 模块14.5批次一验收报告

分支 codex/m145；用户验收、合并待确认。测试数字及体积在实际验证结束后补全。

## 最终方案

ThreadingMixIn + WSGIServer、daemon_threads=True；聊天锁内准备→锁外模型调用→锁内保存，其他请求的复合操作锁及Store内部RLock保留。审核/发布/回滚/恢复/摘要/候选提取保持一致；清空/恢复增加数据代次，旧请求不写回，保存前复查开关。

config/chat.json（安装位置backend/config/chat.json）默认10轮/6000字符：标准库JSON无需依赖、绝对定位不依赖工作目录。只使用已保存且consent=true的完整conversation_turn，超预算从最旧整轮移除，未保存轮次不补入，system组成不变。

model_config.py统一读取供应商/base_url/模型/Key引用，注册结构预留扩展；本批智谱glm-4-flash，保留既有DeepSeek适配器。地址及模型无代码默认值，Key不入客户端/日志/补丁；真实API默认关闭。

## 底座与应用入口

本入口仅适用于666e2e2纯净底座：b0已回退、install-state.json的patch_id=null；保留backup/m145-b0不影响应用。

1. 关闭App及本地后端，包括监督程序/自启实例。
2. 单独解压m145-b1-patch.zip；双击补丁目录根部apply_patch.bat，输入现有底座目录。不要把ZIP直接覆盖到底座。
3. 预期“补丁已应用，版本m145-b1”；重开App→设置，版本戳为m145-b1 · 补丁提交短hash。
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

## 前后对比与测试

之前：单线程＋整请求锁、历史0轮、模型地址硬编码。之后：线程化且模型等待不持锁、最多10轮/6000字符、模型配置从环境变量读取。

本机实测：后端87项，82通过、5项Windows专属跳过，0失败；Flutter analyze零问题，Flutter test 24项通过。旧底座在慢模型300ms后释放的场景中，/status耗时301.507ms；新结构5次请求平均6.713ms、最慢8.451ms（模型尚未返回）。Windows全绿结果、正式补丁体积及下载入口将在构建完成后写入仓库最终报告和Release说明。

## 改动文件清单

server/api/app.py；server/memory/store.py；server/memory/context.py；config/chat.json；server/config.py；server/model_config.py；server/providers/__init__.py；server/providers/cloud.py；server/providers/ollama.py；.env.example；tests/test_api.py；tests/test_concurrency.py；tests/test_chat_context.py；tests/test_model_config.py；tests/test_patch_packaging.py；scripts/build_patch.py；scripts/bundle_windows_backend.py；scripts/smoke_patch_bundle.py；.github/workflows/build-backend-patch.yml；.github/workflows/build-windows.yml（补丁工作流入口）；docs/module-145-b1-acceptance.md。

已记录：后续开放轮数/预算调整时入口放设置页，避免手改文件被补丁覆盖；本批不实现该入口。
