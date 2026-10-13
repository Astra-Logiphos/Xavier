import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'appearance.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const XinghuiApp()); }

class XinghuiApp extends StatefulWidget {
  const XinghuiApp({super.key});
  @override
  State<XinghuiApp> createState() => _XinghuiAppState();
}

class _XinghuiAppState extends State<XinghuiApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final api = ApiClient();
  final secure = const FlutterSecureStorage();
  Appearance appearance = Appearance();
  final message = TextEditingController();
  final url = TextEditingController();
  final token = TextEditingController();
  final search = TextEditingController();
  final exclusion = TextEditingController();
  String platform = 'all';
  String mode = 'chat';
  String selectedDate = '';
  String connection = '尚未连接云端';
  int page = 0;
  bool busy = false;
  bool noSave = false;
  bool saveLearning = false;
  bool confirmApi = false;
  Map<String, dynamic> status = {};
  Map<String, dynamic> settings = {};
  Map<String, dynamic> payload = {};
  final List<Map<String, dynamic>> messages = [];
  static const pages = ['今日', '聊天', '学习', '审核与人设', '来源', '记忆', '外观', '设置'];
  static const icons = [Icons.nights_stay_outlined, Icons.chat_bubble_outline,
    Icons.school_outlined, Icons.verified_user_outlined, Icons.travel_explore,
    Icons.psychology_outlined, Icons.palette_outlined, Icons.settings_outlined];

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() {
    message.dispose(); url.dispose(); token.dispose(); search.dispose(); exclusion.dispose();
    super.dispose();
  }
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('appearance');
      if (saved != null) appearance = Appearance.fromJson(jsonDecode(saved));
      api.baseUrl = prefs.getString('server_url') ?? const String.fromEnvironment('SERVER_URL');
      api.token = await secure.read(key: 'access_token') ?? '';
      url.text = api.baseUrl; token.text = api.token;
      if (mounted) setState(() {});
      if (api.baseUrl.isNotEmpty) await refresh();
    } catch (e) { notice('设置加载失败：$e'); }
  }
  void notice(String text) {
    if (mounted) messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; });
    try { await action(); if (mounted) setState(() { connection = '云端已连接'; }); }
    catch (e) { if (mounted) setState(() { connection = '请求失败 / 离线'; }); notice('$e'); }
    finally { if (mounted) setState(() { busy = false; }); }
  }
  Future<void> refresh() async {
    await run(() async {
      status = await api.request('GET', '/status');
      settings = await api.request('GET', '/settings');
      final endpoints = ['/daily${selectedDate.isEmpty ? '' : '?date=$selectedDate'}', '',
        '/learning', '/review', '/sources', '/memories', '', ''];
      if (endpoints[page].isNotEmpty) payload = await api.request('GET', endpoints[page]);
    });
  }
  Future<Map<String, dynamic>?> edit(String title, Map<String, dynamic> initial) async {
    final controller = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(initial));
    final result = await showDialog<Map<String, dynamic>>(context: navigatorKey.currentContext!, builder: (ctx) =>
      AlertDialog(title: Text(title), content: SizedBox(width: 620, child: SingleChildScrollView(
        child: TextField(controller: controller, minLines: 8, maxLines: 18,
          decoration: const InputDecoration(helperText: 'JSON 编辑器；修改引号内文字，保留字段与格式')))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            try { final parsed = jsonDecode(controller.text) as Map<String, dynamic>;
              Navigator.pop(ctx, parsed); }
            catch (_) { notice('JSON 格式不正确'); }
          }, child: const Text('保存'))]));
    controller.dispose(); return result;
  }
  Future<void> showData(String title, Object data) async {
    await showDialog<void>(context: navigatorKey.currentContext!, builder: (ctx) => AlertDialog(
      title: Text(title), content: SizedBox(width: 720, child: SingleChildScrollView(
        child: SelectableText(data is String ? data : const JsonEncoder.withIndent('  ').convert(data)))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))]));
  }
  Future<bool> confirm(String title, String text) async => await showDialog<bool>(
    context: navigatorKey.currentContext!, builder: (ctx) => AlertDialog(title: Text(title), content: Text(text), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认'))])) ?? false;
  Future<void> mutate(String method, String path, Map<String, dynamic> body) async {
    await run(() async { final out = await api.request(method, path, body);
      notice(out['notice']?.toString() ?? '已保存'); });
    await refresh();
  }
  Future<void> newRecord(String title, String path, Map<String, dynamic> initial) async {
    final data = await edit(title, initial);
    if (data != null) await mutate('POST', path, data);
  }
  Future<void> saveAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance', jsonEncode(appearance.toJson()));
    if (mounted) setState(() {});
  }
  Future<void> chooseBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom,
      allowedExtensions: ['png','jpg','jpeg','webp']);
    if (result == null || result.files.single.path == null) return;
    final selected = result.files.single;
    if (selected.size > 10 * 1024 * 1024) { notice('请选择小于 10 MB 的图片'); return; }
    final root = await getApplicationSupportDirectory();
    final source = File(selected.path!);
    // Persist only an explicitly selected background. Never upload it to the server.
    final destination = '${root.path}/custom_background.${selected.extension}';
    final previous = appearance.backgroundPath;
    await source.copy(destination);
    if (previous != null && previous != destination && await File(previous).exists()) {
      await File(previous).delete();
    }
    appearance.backgroundPath = destination;
    await saveAppearance();
  }
  Future<void> exportFile(String name, String contents) async {
    final bytes = utf8.encode(contents);
    final result = await FilePicker.platform.saveFile(dialogTitle: '保存导出（包含个人信息）',
      fileName: name, type: FileType.custom, allowedExtensions: [name.split('.').last],
      bytes: Platform.isAndroid ? Uint8List.fromList(bytes) : null);
    if (result == null) return;
    if (!Platform.isAndroid) await File(result).writeAsString(contents);
    notice('已导出；请自行保护该文件，不要提交到 GitHub。');
  }
  Future<void> send() async {
    final text = message.text.trim(); if (text.isEmpty) return;
    await run(() async {
      final out = await api.request('POST', '/chat', {'text': text, 'mode': mode,
        'no_save': noSave, 'save_learning': saveLearning, 'api_confirmed': confirmApi});
      if (mounted) setState(() { messages.add({'user': text, 'reply': out['reply'],
        'saved': out['saved'], 'emotion': out['emotion'], 'turn_id': out['turn_id']}); message.clear(); });
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(navigatorKey: navigatorKey, scaffoldMessengerKey: messengerKey, title: '星回 · 陪你慢慢来', debugShowCheckedModeBanner: false,
      theme: appearance.materialTheme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(appearance.textScale)), child: child!),
      home: Builder(builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('星回 · 陪你慢慢来'), actions: [
          Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(connection))),
          IconButton(onPressed: busy ? null : refresh, tooltip: '刷新网络状态', icon: const Icon(Icons.refresh))]),
        body: Stack(children: [
          if (appearance.backgroundPath != null) Positioned.fill(child: Image.file(
            File(appearance.backgroundPath!), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          Positioned.fill(child: ColoredBox(color: Theme.of(context).colorScheme.surface.withOpacity(appearance.overlay))),
          LayoutBuilder(builder: (ctx, constraints) => Row(children: [
            if (constraints.maxWidth >= 850) NavigationRail(selectedIndex: page,
              onDestinationSelected: (i) { setState(() { page = i; payload = {}; }); refresh(); },
              labelType: NavigationRailLabelType.all,
              destinations: List.generate(pages.length, (i) => NavigationRailDestination(
                icon: Icon(icons[i]), label: Text(pages[i])))),
            Expanded(child: Column(children: [if (busy) const LinearProgressIndicator(),
              Expanded(child: Padding(padding: const EdgeInsets.all(20), child: content(ctx))) ])),
          ])),
        ]),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 850 ? SizedBox(height: 76,
          child: ListView(scrollDirection: Axis.horizontal, children: List.generate(pages.length, (i) =>
            Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: TextButton(
              onPressed: () { setState(() { page = i; payload = {}; }); refresh(); },
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icons[i]), Text(pages[i])])))))) : null,
      )));
  }
  Widget content(BuildContext context) => switch (page) {
    0 => home(), 1 => chat(), 2 => learning(), 3 => review(), 4 => sources(),
    5 => memories(), 6 => design(), _ => preferences(),
  };
  Widget heading(String title, String subtitle) => Padding(padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(subtitle)]));
  Widget card(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), const SizedBox(height: 12), child])));
  List<Map<String, dynamic>> get items => (payload['items'] as List? ?? []).cast<Map<String, dynamic>>();
  Widget home() => ListView(children: [heading('今天，也在这里',
    '虚构 AI 角色 · 默认免费规则模式 · 人设 ${status['persona_version'] ?? '未连接'}'),
    Wrap(spacing: 8, children: ['学习','情绪','陪伴'].map((cat) => FilledButton.tonalIcon(
      onPressed: busy ? null : () => mutate('POST','/checkins',{'category':cat}),
      icon: const Icon(Icons.check_circle_outline), label: Text('$cat打卡'))).toList()),
    TextButton(onPressed: () => newRecord('自定义 / 补卡','/checkins',
      {'category':'学习','local_date':selectedDate.isEmpty ? DateTime.now().toIso8601String().substring(0,10) : selectedDate}),
      child: const Text('自定义打卡与补卡')),
    TextButton(onPressed: () async { await run(() async { await showData('打卡与连续天数',await api.request('GET','/checkins')); }); }, child: const Text('查看连续天数')),
    TextButton.icon(onPressed: () async {
      final d = await showDatePicker(context: navigatorKey.currentContext!, firstDate: DateTime(2020),
        lastDate: DateTime.now(), initialDate: DateTime.now());
      if (d != null) { selectedDate = d.toIso8601String().substring(0,10); await refresh(); }
    }, icon: const Icon(Icons.calendar_month), label: Text(selectedDate.isEmpty ? '按日期回顾' : selectedDate)),
    card('今日摘要', SelectableText(const JsonEncoder.withIndent('  ').convert(payload['summary'] ?? {'notice':'连接云端后可查看。聊天保存默认关闭。'}))),
    card('最近对话', Column(children: (payload['turns'] as List? ?? []).reversed.take(8).map((r) =>
      ListTile(title: Text(r['user_text']), subtitle: Text(r['assistant_text']))).toList())),
  ]);
  Widget chat() => Column(children: [heading('慢慢说，我在听', '没有模型 Key 也能使用免费规则模式；真实模型需要后端配置。'),
    Wrap(spacing: 10, runSpacing: 4, children: [DropdownButton<String>(value: mode, items: const [
      DropdownMenuItem(value:'chat',child:Text('陪伴')), DropdownMenuItem(value:'learning',child:Text('学习')),
      DropdownMenuItem(value:'professional',child:Text('专业问答')), DropdownMenuItem(value:'research',child:Text('科研解释')),
      DropdownMenuItem(value:'code',child:Text('代码解释')), DropdownMenuItem(value:'paper',child:Text('论文阅读'))],
      onChanged: (v) => setState(() { mode = v!; })),
      FilterChip(label: const Text('本轮不保存'), selected: noSave, onSelected:(v)=>setState(()=>noSave=v)),
      FilterChip(label: const Text('同意保存学习记录'),selected:saveLearning,onSelected:(v)=>setState(()=>saveLearning=v)),
      FilterChip(label: const Text('确认本轮云端 API'),selected:confirmApi,onSelected:(v)=>setState(()=>confirmApi=v))]),
    Expanded(child: ListView(children: messages.map((m) => card('你：${m['user']}', Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [SelectableText('${m['reply']}'),
      Text('保存：${m['saved']} · 情绪候选：${m['emotion']}'),
      Wrap(children: [IconButton(tooltip:'语音播放（模拟）',icon:const Icon(Icons.volume_up_outlined),
        onPressed:()=>run(() async { await showData('语音接口',await api.request('POST','/voice/tts',{'text':m['reply']})); })),
        if (m['turn_id'] != null) TextButton(onPressed: () async {
          final data = await edit('修正情绪',{'label':'calm'});
          if (data != null) await mutate('PATCH','/emotion/${m['turn_id']}',data);
        },child:const Text('修正情绪'))])]))).toList())),
    Row(children:[IconButton(tooltip:'语音输入（模拟；没有录音）',icon:const Icon(Icons.mic_none),
      onPressed:()=>notice('语音输入尚为模拟接口，没有录音；请先使用文本输入。')),
      Expanded(child:TextField(controller:message,minLines:1,maxLines:5,
        decoration:const InputDecoration(hintText:'输入消息；“今天学了深度学习”可记录学习主题'),onSubmitted:(_)=>send())),
      IconButton(onPressed:busy?null:send,icon:const Icon(Icons.send_rounded))])]);
  Widget learning() => ListView(children:[heading('我们学到哪里了', '只回顾真实保存的学习记录；公式和专业事实不被语气修改。'),
    FilledButton.icon(onPressed:()=>newRecord('添加学习记录','/learning',{'topic':'深度学习',
      'knowledge_points':['在这里填写学过的知识点'],'consent':true}),icon:const Icon(Icons.add),label:const Text('添加学习记录')),
    ...items.map((r)=>card(r['topic'] ?? '',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${r['learning_date']} · 已复习 ${r['review_count']} 次 · 下次 ${r['next_review_at']}'),
      Text('知识点：${r['knowledge_points']}'),Wrap(children:[
        TextButton(onPressed:()=>mutate('POST',"/learning/${r['id']}/review",{}),child:const Text('完成复习')),
        TextButton(onPressed:()=>run(() async { await showData('学习自测',await api.request('GET',"/learning/${r['id']}/quiz")); }),child:const Text('自测')),
        TextButton(onPressed:() async { final data=await edit('掌握、错题与自己的理解',{
          'mastered':r['mastered'],'unmastered':r['unmastered'],'mistakes':r['mistakes'],'user_understanding':r['user_understanding']});
          if(data!=null) await mutate('PATCH',"/learning/${r['id']}",data); },child:const Text('编辑学习状态'))])])))]);
  Widget review() => ListView(children:[heading('人设审核中心','待审核来源 ${status['pending_sources'] ?? '—'} · 修改后须通过策略回归才能生效。'),
    Wrap(spacing:8,children:[
      FilledButton.tonal(onPressed:()=>newRecord('显式人设偏好','/traits',{'text':'更主动一些','layer':'user_preference'}),child:const Text('添加我的偏好')),
      TextButton(onPressed:()=>newRecord('从已审核来源提取特征','/traits',{'text':'必要的结构化特征','layer':'community_evidence','source_id':'填写已批准来源 ID','confidence':0.8}),child:const Text('添加有来源特征')),
      TextButton(onPressed:()=>run(() async { await showData('全部特征与来源',await api.request('GET','/traits')); }),child:const Text('查看生效 / 暂停特征')),
      TextButton(onPressed:()=>run(() async {
        final out=await api.request('GET','/persona/versions');
        await showDialog<void>(context:navigatorKey.currentContext!,builder:(ctx)=>AlertDialog(title:const Text('人设版本历史'),
          content:SizedBox(width:620,child:SingleChildScrollView(child:Column(children:(out['items'] as List).map((v)=>ListTile(
            title:Text('${v['version_id']} · ${v['status']}'),subtitle:Text('${v['change_summary']}'),
            trailing:TextButton(onPressed:() async { Navigator.pop(ctx); if(await confirm('回滚人设','回滚至 ${v['version_id']}？')) {
              await api.request('POST','/persona/rollback',{'id':v['id']}); } },child:const Text('回滚')))).toList()))),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('关闭'))]));
      }),child:const Text('历史与回滚')),
      TextButton(onPressed:()=>run(() async { final out=await api.request('GET','/persona/export');
        await exportFile('persona.json',const JsonEncoder.withIndent('  ').convert(out['json'])); }),child:const Text('导出 JSON')),
      TextButton(onPressed:()=>run(() async { final out=await api.request('GET','/persona/export');
        await exportFile('persona.md',out['markdown']); }),child:const Text('导出 Markdown')),
      TextButton(onPressed:()=>run(() async { final out=await api.request('GET','/persona/eval');
        await exportFile('persona_eval_report.md',out['report_markdown']); }),child:const Text('回归报告')),
      TextButton(onPressed:()=>run(() async { final out=await api.request('GET','/traits');
        await showDialog<void>(context:navigatorKey.currentContext!,builder:(ctx)=>AlertDialog(title:const Text('特征管理'),
          content:SizedBox(width:620,child:SingleChildScrollView(child:Column(children:(out['items'] as List).map((t)=>ListTile(
            title:Text('${t['text']}'),subtitle:Text('${t['layer']} · ${t['review_status']} · 来源 ${t['source_url']}'),
            trailing:Wrap(children:[IconButton(icon:Icon(t['paused']==true?Icons.play_arrow:Icons.pause),onPressed:() async {
              Navigator.pop(ctx); await api.request('PATCH',"/traits/${t['id']}",{'paused':t['paused']!=true}); }),
              IconButton(icon:const Icon(Icons.edit),onPressed:() async {Navigator.pop(ctx);
                final d=await edit('编辑特征 / 解决冲突',{'text':t['text'],'possible_conflicts':t['possible_conflicts']});
                if(d!=null) await api.request('PATCH',"/traits/${t['id']}",d); }),
              IconButton(icon:const Icon(Icons.delete_outline),onPressed:() async { Navigator.pop(ctx);
                if(await confirm('删除特征','同时清除历史快照中的该特征？')) await api.request('DELETE',"/traits/${t['id']}"); })]))).toList()))),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('关闭'))]));
      }),child:const Text('暂停 / 编辑 / 删除')),
      TextButton(onPressed:() async { final d=await edit('比较版本 ID',{'left':'左侧记录 ID','right':'右侧记录 ID'});
        if(d!=null) await run(() async { await showData('人设差异',await api.request('GET','/persona/diff?left=${Uri.encodeQueryComponent(d['left'])}&right=${Uri.encodeQueryComponent(d['right'])}')); }); },child:const Text('比较版本')),
    ]),
    ...items.map((r)=>card(r['title'] ?? r['text'] ?? '待审核',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SelectableText('ID: ${r['id']}\n类型：${r['kind']} · ${r['layer'] ?? r['source_type']}\n来源：${r['source_url']}\n冲突：${r['possible_conflicts'] ?? '待核对'}'),
      if(r['claims']!=null) SelectableText(const JsonEncoder.withIndent('  ').convert(r['claims'])),
      Wrap(children:['approve','reject','defer','conflict'].map((action)=>TextButton(onPressed:()=>mutate('POST','/review',{'id':r['id'],'action':action}),
        child:Text({'approve':'批准','reject':'拒绝','defer':'暂缓','conflict':'冲突'}[action]!))).toList()),
      TextButton(onPressed:()=>run(() async { await showData('静态示例预览',await api.request('POST','/persona/preview',{'text':r['text']??r['title']})); }),child:const Text('预览语气'))])))]);
  Widget sources() => ListView(children:[heading('来源搜索与导入','搜索范围是已导入来源。自动平台搜索未授权；所有导入均进入待审核。'),
    Row(children:[Expanded(child:TextField(controller:search,decoration:const InputDecoration(labelText:'关键词，如沈星回 性格'))),
      IconButton(icon:const Icon(Icons.search),onPressed:()=>run(() async {
        payload=await api.request('GET','/sources?q=${Uri.encodeQueryComponent(search.text)}&exclude=${Uri.encodeQueryComponent(exclusion.text)}${platform=='all'?'':'&platform=$platform'}'); }))]),
    TextField(controller:exclusion,decoration:const InputDecoration(labelText:'排除关键词')),
    DropdownButton<String>(value:platform,items:['all','manual','xiaohongshu','bilibili','public_web'].map((p)=>DropdownMenuItem(value:p,child:Text(p))).toList(),onChanged:(v)=>setState(()=>platform=v!)),
    FilledButton.tonal(onPressed:()=>newRecord('URL / 授权文字导入','/sources',{
      'url':'https://example.org/your-source','title':'填写标题','author':'填写作者','published_at':'填写发布时间',
      'platform':'manual','content_type':'user_provided_text','source_version':'','text':'仅粘贴有权使用的必要文字，避免完整转载与私人信息'}),child:const Text('导入来源')),
    ...items.map((r)=>card(r['title'],Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SelectableText('ID: ${r['id']}\n${r['platform']} · ${r['source_type']} · ${r['evidence_status']}\n作者：${r['author']} · ${r['published_at']}\n抓取/导入：${r['fetched_at']}\n${r['source_url']}'),
      TextButton(onPressed:() async { final uri=Uri.tryParse(r['source_url']);
        if(uri!=null && uri.scheme=='https') await launchUrl(uri,mode:LaunchMode.externalApplication); },child:const Text('打开原始链接')),
      TextButton(onPressed:() async { final d=await edit('人工标记来源',{'source_type':r['source_type'],'source_version':r['source_version'],'evidence_status':r['evidence_status']});
        if(d!=null) await mutate('PATCH',"/sources/${r['id']}",d); },child:const Text('标记官方 / 粉丝观点 / 不可靠')),
      TextButton(onPressed:()=>showData('声明与摘录',r['claims']),child:const Text('查看事实声明 / 观点'))])))]);
  Widget memories() => ListView(children:[heading('我的记忆','低置信度记录不参与检索；删除后不能继续检索。'),
    FilledButton.tonal(onPressed:()=>newRecord('明确记住这件事','/memories',{
      'kind':'profile_memory','content':'我喜欢星空','consent':true,'confidence':1.0}),child:const Text('添加记忆')),
    ...items.map((r)=>card(r['content']??r['topic']??'',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${r['kind']} · 同意 ${r['consent']} · 置信度 ${r['confidence']} · ${r['review_status']}\n来源：${r['source']} · 更新：${r['updated_at']}'),
      Wrap(children:[TextButton(onPressed:() async { final d=await edit('修改记忆',{'content':r['content']??r['topic'],'consent':true,'confidence':r['confidence']});
        if(d!=null) await mutate('PATCH',"/memories/${r['id']}",d); },child:const Text('编辑')),
        TextButton(onPressed:() async {if(await confirm('忘记这件事','删除后不再检索这条记忆？')) await mutate('DELETE',"/memories/${r['id']}",{});},child:const Text('删除'))])])))]);
  Widget design() => ListView(children:[heading('让这里成为你喜欢的样子','主题、背景与界面参数可随时切换。背景只保存在应用设备，不上传云端。'),
    card('主题',Wrap(spacing:12,children:Appearance.themes.keys.map((name)=>ChoiceChip(
      label:Text(name),selected:appearance.theme==name,onSelected:(_){appearance.theme=name;saveAppearance();})).toList())),
    card('自定义背景',Wrap(children:[FilledButton.tonalIcon(onPressed:chooseBackground,
      icon:const Icon(Icons.image_outlined),label:const Text('选择背景图片')),
      TextButton(onPressed:() async { final previous=appearance.backgroundPath;
        appearance.backgroundPath=null; await saveAppearance();
        if(previous!=null && await File(previous).exists()) await File(previous).delete(); },child:const Text('移除背景'))])),
    card('界面自定义',Column(children:[Text('背景遮罩 ${(appearance.overlay*100).round()}%'),
      Slider(value:appearance.overlay,min:.4,max:.98,onChanged:(v){setState(()=>appearance.overlay=v);},onChangeEnd:(_)=>saveAppearance()),
      Text('卡片圆角 ${appearance.radius.round()}'),Slider(value:appearance.radius,min:0,max:32,
        onChanged:(v)=>setState(()=>appearance.radius=v),onChangeEnd:(_)=>saveAppearance()),
      Text('文字大小 ${appearance.textScale.toStringAsFixed(2)}'),Slider(value:appearance.textScale,min:.85,max:1.4,
        onChanged:(v)=>setState(()=>appearance.textScale=v),onChangeEnd:(_)=>saveAppearance())])),
    TextButton(onPressed:() async { final d=await edit('导入外观配置',appearance.toJson()..remove('backgroundPath'));
      if(d!=null){final background=appearance.backgroundPath;appearance=Appearance.fromJson(d);appearance.backgroundPath=background;await saveAppearance();}},child:const Text('编辑主题参数 JSON')),
    TextButton(onPressed:()=>exportFile('appearance.json',jsonEncode(appearance.toJson()..remove('backgroundPath'))),child:const Text('导出主题参数'))]);
  Widget preferences() => ListView(children:[heading('设置与隐私','这里填写应用访问令牌，不是模型 API Key。模型 Key 只在后端配置。'),
    TextField(controller:url,decoration:const InputDecoration(labelText:'HTTPS 云端后端地址')),
    const SizedBox(height:12),TextField(controller:token,obscureText:true,decoration:const InputDecoration(labelText:'应用访问令牌 AUTH_TOKEN')),
    FilledButton(onPressed:() async { api.baseUrl=url.text.trim();api.token=token.text.trim();
      try{final prefs=await SharedPreferences.getInstance();await prefs.setString('server_url',api.baseUrl);
        await secure.write(key:'access_token',value:api.token);await refresh();}
      catch(e){notice('凭据安全保存失败：$e');}},child:const Text('保存并连接')),
    card('模型与服务状态',SelectableText(const JsonEncoder.withIndent('  ').convert(status))),
    ...['save_conversations','emotion_enabled','voice_enabled','reminders_enabled','reminders_paused'].map((key)=>SwitchListTile(
      title:Text({'save_conversations':'保存聊天（默认关闭）','emotion_enabled':'情绪候选判断','voice_enabled':'语音（目前模拟）',
        'reminders_enabled':'提醒偏好（通知调度未接入）','reminders_paused':'暂停提醒'}[key]!),
      value:settings[key]==true,onChanged:(v)=>mutate('PATCH','/settings',{key:v}))),
    DropdownButton<String>(value:settings['language']??'zh-CN',items:['zh-CN','en-US','ja-JP'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
      onChanged:(v)=>mutate('PATCH','/settings',{'language':v})),
    TextButton(onPressed:()=>run(() async { final data=await api.request('GET','/data/export');
      await exportFile('xinghui-personal-export.json',const JsonEncoder.withIndent('  ').convert(data)); }),child:const Text('导出个人数据')),
    TextButton(onPressed:() async { if(await confirm('删除全部个人数据','将清除当前云端数据库中的聊天、记忆、学习、打卡、人设版本与偏好。外部备份需部署者另外删除。')) {
      await mutate('DELETE','/data',{'confirmation':'DELETE_ALL'}); if(mounted)setState(()=>messages.clear());
    } },child:const Text('删除全部个人数据')),
    const Text('离线时仅显示当前会话已有内容和外观设置；不排队发送，也不宣称具备本地大模型。')]);
}
