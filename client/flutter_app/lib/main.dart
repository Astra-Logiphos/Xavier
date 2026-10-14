import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bubble_config.dart';
import 'chat_page.dart';
import 'avatar_store.dart';
import 'connection_monitor.dart';
import 'performance_probe.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'appearance.dart';
import 'theme_config.dart';
import 'persona_assets.dart';
import 'companion_ui.dart';
import 'ambient_background.dart';
import 'background_library.dart';
import 'nutrition_page.dart';
import 'health_store.dart';
import 'reminder_service.dart';
import 'personal_backup.dart';
import 'record_editor.dart';
import 'version_stamp.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await VersionStamp.load();
  if (arguments.contains('--version-stamp-smoke')) {
    await File(
            '${File(Platform.resolvedExecutable).parent.path}/version-stamp-smoke.txt')
        .writeAsString(VersionStamp.current, flush: true);
    exit(0);
  }
  await Future.wait([
    ThemeConfig.load(),
    BubbleConfig.load(),
    PersonaAssets.load(),
    HealthStore.instance.open()
  ]);
  if (arguments.contains('--bubble-config-smoke')) {
    await File(
            '${File(Platform.resolvedExecutable).parent.path}/bubble-config-smoke.json')
        .writeAsString(jsonEncode({
      'companionLightColor': BubbleConfig.skin['companionLightColor'],
      'avatarSize': BubbleConfig.skin['avatar']['size'],
      'error': BubbleConfig.error
    }));
    exit(BubbleConfig.error == null ? 0 : 1);
  }
  if (arguments.any((arg) => arg.startsWith('--avatar-smoke'))) {
    final store = AvatarStore();
    await store.load();
    if (arguments.first == '--avatar-smoke-import') {
      await store.importFile(File(arguments[1]));
    }
    if (arguments.first == '--avatar-smoke-reset') await store.reset();
    await File(
            '${File(Platform.resolvedExecutable).parent.path}/avatar-smoke.json')
        .writeAsString(jsonEncode({
      'path': store.path,
      'exists': store.path != null && await File(store.path!).exists()
    }));
    exit(0);
  }
  if (const bool.fromEnvironment('PERFORMANCE_PROBE')) {
    runApp(const PerformanceProbe());
    return;
  }
  await ReminderService.instance.load();
  try {
    await ReminderService.instance
        .reschedule(maintenance: arguments.contains('--refresh-reminders'));
  } catch (e) {
    ReminderService.instance.error = '$e';
  }
  if (arguments.contains('--notification-smoke')) {
    try {
      await ReminderService.instance.smoke();
      exit(0);
    } catch (e) {
      await File(
              '${File(Platform.resolvedExecutable).parent.path}/notification-smoke.json')
          .writeAsString(jsonEncode({'passed': false, 'error': '$e'}));
      exit(1);
    }
  }
  if (arguments.contains('--refresh-reminders')) {
    exit(ReminderService.instance.error == null ? 0 : 1);
  }
  runApp(const XinghuiApp());
}

class XinghuiApp extends StatefulWidget {
  final ApiClient? client;
  const XinghuiApp({super.key, this.client});
  @override
  State<XinghuiApp> createState() => _XinghuiAppState();
}

class _XinghuiAppState extends State<XinghuiApp> {
  final avatars = AvatarStore();
  ConnectionMonitor? healthMonitor;
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ApiClient api;
  final secure = const FlutterSecureStorage();
  Appearance appearance = Appearance();
  final message = TextEditingController();
  final chatScroll = ScrollController();
  final url = TextEditingController();
  final token = TextEditingController();
  final search = TextEditingController();
  final exclusion = TextEditingController();
  String platform = 'all';
  String mode = 'chat';
  String selectedDate = '';
  String connection = '尚未连接本地';
  int page = 0;
  bool busy = false;
  bool connected = false;
  Timer? personaClock;
  bool noSave = false;
  bool saveLearning = false;
  bool confirmApi = false;
  Map<String, dynamic> status = {};
  Map<String, dynamic> settings = {};
  Map<String, dynamic> payload = {};
  final List<Map<String, dynamic>> messages = [];
  List<GalleryPhoto> gallery = [];
  static const pages = [
    '今日',
    '聊天',
    '学习',
    '审核与人设',
    '来源',
    '记忆',
    '外观',
    '设置',
    '学习规则',
    '关于星回',
    '热量追踪'
  ];
  static const icons = [
    Icons.nights_stay_outlined,
    Icons.chat_bubble_outline,
    Icons.school_outlined,
    Icons.verified_user_outlined,
    Icons.travel_explore,
    Icons.psychology_outlined,
    Icons.palette_outlined,
    Icons.settings_outlined,
    Icons.auto_awesome_outlined,
    Icons.person_outline,
    Icons.restaurant_outlined
  ];

  @override
  void initState() {
    super.initState();
    api = widget.client ?? ApiClient();
    load();
    var clockTheme = appearance.effectiveTheme;
    personaClock = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentTheme = appearance.effectiveTheme;
      if (mounted && (page != 1 || currentTheme != clockTheme)) setState(() {});
      clockTheme = currentTheme;
    });
  }

  @override
  void dispose() {
    healthMonitor?.dispose();
    personaClock?.cancel();
    chatScroll.dispose();
    message.dispose();
    url.dispose();
    token.dispose();
    search.dispose();
    exclusion.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      if (!BubbleConfig.loaded) await BubbleConfig.load();
      final prefs = await SharedPreferences.getInstance();
      gallery = await BackgroundLibrary.load();
      await avatars.load();
      final saved = prefs.getString('appearance');
      if (saved != null) appearance = Appearance.fromJson(jsonDecode(saved));
      api.baseUrl = prefs.getString('server_url') ?? '';
      if (Platform.isWindows && api.baseUrl.isEmpty) {
        final directory = Platform.environment['LOCALAPPDATA'];
        if (directory != null) {
          final file =
              File('$directory/XinghuiCompanion/backend/auth_token.txt');
          if (await file.exists()) {
            api.baseUrl = 'http://127.0.0.1:8080';
            api.token = (await file.readAsString()).trim();
          }
        }
      }
      api.token = await secure.read(key: 'access_token') ?? api.token;
      url.text = api.baseUrl;
      token.text = api.token;
      if (mounted) setState(() {});
      await refresh();
      if (Platform.environment['XINGHUI_LAUNCH_SMOKE'] == '1') {
        await File(
                '${File(Platform.resolvedExecutable).parent.path}/start-all-smoke.json')
            .writeAsString(jsonEncode(
                {'connected': connected, 'provider': status['provider']}));
      }
      healthMonitor = ConnectionMonitor(api, (healthy) {
        if (mounted) {
          setState(() {
            connected = healthy;
            connection = healthy ? '本地已连接' : '本地后端未连接';
          });
        }
      }, refresh)
        ..start();
    } catch (e) {
      notice('设置加载失败：$e');
    }
  }

  void notice(String text) {
    if (mounted) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          connected = api.baseUrl.isNotEmpty;
          connection = connected ? '本地已连接' : '尚未连接本地后端';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connected = e is ApiException;
          connection = connected ? '本地已连接' : '本地后端未连接';
        });
      }
      notice('$e');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    await run(() async {
      status = await api.request('GET', '/status');
      settings = await api.request('GET', '/settings');
      if (api.baseUrl.isNotEmpty) {
        final history = await api.request('GET', '/conversations');
        final transient =
            messages.where((row) => row['saved'] != true).toList();
        messages.clear();
        messages
            .addAll((history['items'] as List).map((row) => <String, dynamic>{
                  'user': row['user_text'],
                  'reply': row['assistant_text'],
                  'saved': true,
                  'emotion': row['emotion'],
                  'turn_id': row['id'],
                  'created_at': row['created_at'],
                }));
        messages.addAll(transient);
      }
      final endpoints = [
        '/daily${selectedDate.isEmpty ? '' : '?date=$selectedDate'}',
        '',
        '/learning',
        '/review',
        '/sources',
        '/memories',
        '',
        '',
        '/rules',
        '',
        ''
      ];
      if (endpoints[page].isNotEmpty) {
        payload = await api.request('GET', endpoints[page]);
      }
      if (api.baseUrl.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('weekly_backup_suggested') != true) {
          await prefs.setBool('weekly_backup_suggested', true);
          notice('建议每周备份一次：设置 → 一键备份全部数据。');
        }
      }
    });
    healthMonitor?.schedule();
    if (page == 1) scrollLatest();
  }

  Future<Map<String, dynamic>?> edit(
      String title, Map<String, dynamic> initial) async {
    return showDialog<Map<String, dynamic>>(
        context: navigatorKey.currentContext!,
        builder: (_) => RecordEditor(title: title, initial: initial));
  }

  Future<void> showData(String title, Object data) async {
    await showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (ctx) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                    width: 720,
                    child: SingleChildScrollView(
                        child: SelectableText(
                            data is String ? data : readableData(data)))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'))
                ]));
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
          context: navigatorKey.currentContext!,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('确认'))
              ])) ??
      false;
  Future<void> mutate(
      String method, String path, Map<String, dynamic> body) async {
    await run(() async {
      final out = await api.request(method, path, body);
      notice(path == '/checkins'
          ? PersonaAssets.line('鼓励', body['category'] as String? ?? '学习')
          : out['notice']?.toString() ?? '已保存');
    });
    await refresh();
  }

  Future<void> newRecord(
      String title, String path, Map<String, dynamic> initial) async {
    final data = await edit(title, initial);
    if (data != null) await mutate('POST', path, data);
  }

  Future<void> saveAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance', jsonEncode(appearance.toJson()));
    if (mounted) setState(() {});
  }

  Future<void> chooseBackground() async {
    try {
      final photo =
          await BackgroundLibrary.import(navigatorKey.currentContext!);
      if (photo == null) return;
      gallery.add(photo);
      await BackgroundLibrary.save(gallery);
      appearance.backgroundPath = photo.path;
      appearance.autoTheme = false;
      await saveAppearance();
    } catch (error) {
      notice('导入失败：$error');
    }
  }

  Future<void> exportFile(String name, String contents) async {
    final bytes = utf8.encode(contents);
    final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存导出（包含个人信息）',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [name.split('.').last],
        bytes: Platform.isAndroid ? Uint8List.fromList(bytes) : null);
    if (result == null) return;
    if (!Platform.isAndroid) await File(result).writeAsString(contents);
    notice('已导出；请自行保护该文件，不要提交到 GitHub。');
  }

  Future<void> connectLocal() async {
    if (!Platform.isWindows) {
      notice('当前模块只交付 Windows 本地连接。');
      return;
    }
    final directory = Platform.environment['LOCALAPPDATA'];
    if (directory == null) {
      notice('无法定位本地数据目录。');
      return;
    }
    final file = File('$directory/XinghuiCompanion/backend/auth_token.txt');
    if (!await file.exists()) {
      notice('请先双击 start_backend.bat，再点击连接本地后端。');
      return;
    }
    api.baseUrl = 'http://127.0.0.1:8080';
    api.token = (await file.readAsString()).trim();
    url.text = api.baseUrl;
    token.text = api.token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', api.baseUrl);
      await secure.write(key: 'access_token', value: api.token);
      await refresh();
    } catch (e) {
      notice('连接失败：$e');
    }
  }

  void scrollLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !chatScroll.hasClients || !BubbleConfig.loaded) return;
      final config = BubbleConfig.skin['scroll'];
      chatScroll.animateTo(chatScroll.position.maxScrollExtent,
          duration:
              Duration(milliseconds: (config['durationMs'] as num).toInt()),
          curve: config['curve'] == 'easeOut' ? Curves.easeOut : Curves.linear);
    });
  }

  Future<void> send() async {
    final text = message.text.trim();
    if (text.isEmpty || busy) return;
    final row = <String, dynamic>{
      'user': text,
      'reply': null,
      'saved': false,
      'local_id': 'draft-${DateTime.now().microsecondsSinceEpoch}',
      'created_at': DateTime.now().toUtc().toIso8601String()
    };
    final body = {
      'text': text,
      'mode': mode,
      'no_save': noSave,
      'save_learning': saveLearning,
      'api_confirmed': confirmApi
    };
    await run(() async {
      setState(() {
        messages.add(row);
        message.clear();
        confirmApi = false;
      });
      scrollLatest();
      try {
        final out = await api.request('POST', '/chat', body);
        if (row['suppress_save'] == true && out['saved'] == true) {
          try {
            await api.request('DELETE', '/conversations/${out['turn_id']}');
            out['saved'] = false;
            out['turn_id'] = null;
          } catch (e) {
            notice('这一轮已保存，但撤销失败。请完成后重试“本轮不保存”。');
          }
        }
        debugPrint(
            'Chat completed: saved=${out['saved']}, provider=${out['provider']}');
        if (mounted) {
          setState(() {
            row.addAll({
              'reply': out['reply'],
              'saved': out['saved'],
              'emotion': out['emotion'],
              'turn_id': out['turn_id'],
              'assistant_time': out['utc_time']
            });
            noSave = false;
            saveLearning = false;
          });
          scrollLatest();
          try {
            status = await api.request('GET', '/status');
            settings = await api.request('GET', '/settings');
          } catch (e) {
            debugPrint('Post-chat refresh failed: $e');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            messages.remove(row);
            if (message.text.isEmpty) message.text = text;
          });
        }
        rethrow;
      }
    });
  }

  Future<void> chatAction(String action, ChatMessage? selected) async {
    final text = selected?.text ?? message.text.trim();
    final pending = selected != null && selected.turn['reply'] == null;
    if (busy && action != 'copy' && !(action == 'noSave' && pending)) {
      notice('正在发送，完成后再操作。');
      return;
    }
    switch (action) {
      case 'copy':
        if (text.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: text));
          notice('已复制。');
        }
      case 'memory':
        if (text.isEmpty) return;
        if (await confirm('保存到记忆', text)) {
          await mutate('POST', '/memories',
              {'kind': 'profile_memory', 'content': text, 'consent': true});
        }
      case 'read':
        if (text.isEmpty) return;
        await run(() async {
          final result =
              await api.request('POST', '/voice/tts', {'text': text});
          notice(result['notice']?.toString() ?? '语音尚未开放。');
        });
      case 'noSave':
        if (selected == null) {
          setState(() => noSave = !noSave);
          notice(noSave ? '下一轮不保存；发送后恢复默认。' : '下一轮按保存设置处理。');
        } else if (pending) {
          setState(() => selected.turn['suppress_save'] = true);
          notice('这轮完成后将撤销保存。');
        } else if (selected.turn['saved'] == true) {
          if (await confirm('本轮不保存', '撤销这一轮聊天和其记忆候选；此前单独批准的长期记忆保留。')) {
            await run(() async {
              await api.request(
                  'DELETE', '/conversations/${selected.turn['turn_id']}');
              selected.turn['saved'] = false;
              selected.turn['turn_id'] = null;
            });
          }
        } else {
          notice('这一轮未保存。');
        }
      case 'learning':
        if (selected == null) {
          setState(() => saveLearning = !saveLearning);
          notice(saveLearning ? '同意下一轮保存学习记录；发送后恢复默认。' : '下一轮不额外保存学习记录。');
        } else if (text.isNotEmpty) {
          final topic = text.startsWith('今天学了')
              ? text
                  .substring('今天学了'.length)
                  .replaceFirst(RegExp(r'^[：:，, ]+'), '')
              : text;
          if (await confirm('同意保存学习记录', topic)) {
            await mutate('POST', '/learning',
                {'topic': topic, 'consent': true, 'knowledge_points': []});
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        title: ThemeConfig.values['appTitle'] as String,
        debugShowCheckedModeBanner: false,
        theme: appearance.materialTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(appearance.textScale)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                  appBar: AppBar(
                      title: Text(ThemeConfig.values['appTitle'] as String),
                      actions: [
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(child: Text(connection))),
                        IconButton(
                            onPressed: busy ? null : refresh,
                            tooltip: '刷新网络状态',
                            icon: const Icon(Icons.refresh))
                      ]),
                  body: Stack(children: [
                    Positioned.fill(
                        child: AmbientBackground(appearance: appearance)),
                    LayoutBuilder(
                        builder: (ctx, constraints) => Row(children: [
                              if (constraints.maxWidth >= 850)
                                SizedBox(
                                    width: ThemeConfig.number(
                                        'navigation', 'width'),
                                    child: ColoredBox(
                                        color: appearance
                                            .skinColor('background')
                                            .withOpacity((ThemeConfig
                                                        .values['panelOpacity']
                                                    as num)
                                                .toDouble()),
                                        child: ListView(
                                            children: List.generate(
                                                pages.length,
                                                (i) => ListTile(
                                                    selected: page == i,
                                                    leading: Icon(icons[i]),
                                                    title: Text(pages[i]),
                                                    onTap: () {
                                                      setState(() {
                                                        page = i;
                                                        payload = {};
                                                      });
                                                      refresh();
                                                    }))))),
                              Expanded(
                                  child: Column(children: [
                                if (busy) const LinearProgressIndicator(),
                                Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: content(ctx)))
                              ])),
                            ])),
                  ]),
                  bottomNavigationBar: MediaQuery.sizeOf(context).width < 850
                      ? SizedBox(
                          height: 80,
                          child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: List.generate(
                                  pages.length,
                                  (i) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              page = i;
                                              payload = {};
                                            });
                                            refresh();
                                          },
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(icons[i]),
                                                Text(pages[i])
                                              ]))))))
                      : null,
                )));
  }

  Widget content(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(appearance.radius),
      child: ColoredBox(
          color: appearance.skinColor('background').withOpacity(
              (ThemeConfig.values['panelOpacity'] as num).toDouble()),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (page) {
                0 => home(),
                1 => chat(),
                2 => learning(),
                3 => review(),
                4 => sources(),
                5 => memories(),
                6 => design(),
                8 => rules(),
                9 => character(),
                10 => NutritionPage(
                    api: api,
                    connected: connected,
                    onChanged: () {
                      if (mounted) setState(() {});
                    }),
                _ => preferences(),
              })));
  Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(navigatorKey.currentContext!).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle)
      ]));
  Widget card(String title, Widget child) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(navigatorKey.currentContext!)
                    .textTheme
                    .titleMedium),
            const SizedBox(height: 16),
            child
          ])));
  List<Map<String, dynamic>> get items =>
      (payload['items'] as List? ?? []).cast<Map<String, dynamic>>();
  Widget home() => ListView(children: [
        card(
            '今天，也在这里',
            LayoutBuilder(
                builder: (context, box) => box.maxWidth >
                        ThemeConfig.number('hero', 'width') * 2
                    ? Row(children: [
                        const CharacterPortrait(),
                        Expanded(
                            child: Text(PersonaAssets.greeting(DateTime.now()),
                                style: Theme.of(context).textTheme.titleLarge))
                      ])
                    : Column(children: [
                        const CharacterPortrait(),
                        Text(PersonaAssets.greeting(DateTime.now()),
                            style: Theme.of(context).textTheme.titleLarge)
                      ]))),
        Wrap(
            spacing: 8,
            children: ['学习', '情绪', '陪伴']
                .map((cat) => FilledButton.tonalIcon(
                    onPressed: busy
                        ? null
                        : () => mutate('POST', '/checkins', {'category': cat}),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('$cat打卡')))
                .toList()),
        TextButton(
            onPressed: () => newRecord('自定义 / 补卡', '/checkins', {
                  'category': '学习',
                  'local_date': selectedDate.isEmpty
                      ? DateTime.now().toIso8601String().substring(0, 10)
                      : selectedDate
                }),
            child: const Text('自定义打卡与补卡')),
        TextButton(
            onPressed: () async {
              await run(() async {
                await showData(
                    '打卡与连续天数', await api.request('GET', '/checkins'));
              });
            },
            child: const Text('查看连续天数')),
        TextButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                  context: navigatorKey.currentContext!,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDate: DateTime.now());
              if (d != null) {
                selectedDate = d.toIso8601String().substring(0, 10);
                await refresh();
              }
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(selectedDate.isEmpty ? '按日期回顾' : selectedDate)),
        if (!connected)
          card(
              '启动本地后端',
              const Text(
                  '启动本地后端后，聊天与记忆将自动保存。第一步：双击包内 start_backend.bat，再到设置点击“连接本地后端”。不保存的轮次和敏感内容除外。')),
        card(
            '今日热量',
            Text(
                '${HealthStore.date(DateTime.now())} · 净 ${HealthStore.instance.net(HealthStore.date(DateTime.now())).toStringAsFixed(1)} 千卡\n${HealthStore.instance.target > 0 ? '目标 ${HealthStore.instance.target.toStringAsFixed(1)} · 目标缺口 ${(HealthStore.instance.target - HealthStore.instance.net(HealthStore.date(DateTime.now()))).toStringAsFixed(1)} 千卡' : '在设置填写基础代谢与活动系数后显示目标缺口'}')),
        card(
            '今日摘要',
            SelectableText(dailyNarrative(
                (payload['summary'] as Map<String, dynamic>?) ?? {}))),
        card(
            '最近对话',
            Column(
                children: (payload['turns'] as List? ?? [])
                    .reversed
                    .take(8)
                    .map((r) => ListTile(
                        title: Text(r['user_text']),
                        subtitle: Text(r['assistant_text'])))
                    .toList())),
      ]);
  Widget chat() => ChatPage(
      blurEnabled: appearance.blurEnabled,
      userAvatarPath: avatars.path,
      messages: ChatMessage.fromTurns(messages),
      controller: message,
      scrollController: chatScroll,
      busy: busy,
      dark: appearance.dark,
      primary: appearance.skinColor('primary'),
      textColor: appearance.skinColor('text'),
      emptyText: PersonaAssets.empty('聊天'),
      onSend: send,
      onAction: chatAction);
  Widget learning() => ListView(children: [
        heading('我们学到哪里了', '只回顾真实保存的学习记录；公式和专业事实不被语气修改。'),
        FilledButton.icon(
            onPressed: () => newRecord('添加学习记录', '/learning', {
                  'topic': '深度学习',
                  'knowledge_points': ['在这里填写学过的知识点'],
                  'consent': true
                }),
            icon: const Icon(Icons.add),
            label: const Text('添加学习记录')),
        if (items.isEmpty) card('慢慢来', Text(PersonaAssets.empty('学习'))),
        ...items.map((r) => card(
            r['topic'] ?? '',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${r['learning_date']} · 已复习 ${r['review_count']} 次 · 下次 ${r['next_review_at']}'),
              Text('知识点：${(r['knowledge_points'] as List? ?? []).join('；')}'),
              Wrap(children: [
                TextButton(
                    onPressed: () =>
                        mutate('POST', "/learning/${r['id']}/review", {}),
                    child: const Text('完成复习')),
                TextButton(
                    onPressed: () => run(() async {
                          await showData(
                              '学习自测',
                              await api.request(
                                  'GET', "/learning/${r['id']}/quiz"));
                        }),
                    child: const Text('自测')),
                TextButton(
                    onPressed: () async {
                      final data = await edit('掌握、错题与自己的理解', {
                        'mastered': r['mastered'],
                        'unmastered': r['unmastered'],
                        'mistakes': r['mistakes'],
                        'user_understanding': r['user_understanding']
                      });
                      if (data != null) {
                        await mutate('PATCH', "/learning/${r['id']}", data);
                      }
                    },
                    child: const Text('编辑学习状态'))
              ])
            ])))
      ]);
  Widget review() => ListView(children: [
        heading('人设审核中心',
            '待审核来源 ${status['pending_sources'] ?? '—'} · 修改后须通过策略回归才能生效。'),
        Wrap(spacing: 8, children: [
          FilledButton.tonal(
              onPressed: () => newRecord('显式人设偏好', '/traits',
                  {'text': '更主动一些', 'layer': 'user_preference'}),
              child: const Text('添加我的偏好')),
          TextButton(
              onPressed: () => newRecord('从已审核来源提取特征', '/traits', {
                    'text': '必要的结构化特征',
                    'layer': 'community_evidence',
                    'source_id': '填写已批准来源 ID',
                    'confidence': 0.8
                  }),
              child: const Text('添加有来源特征')),
          TextButton(
              onPressed: () => run(() async {
                    await showData(
                        '全部特征与来源', await api.request('GET', '/traits'));
                  }),
              child: const Text('查看生效 / 暂停特征')),
          TextButton(
              onPressed: () => run(() async {
                    final out = await api.request('GET', '/persona/versions');
                    await showDialog<void>(
                        context: navigatorKey.currentContext!,
                        builder: (ctx) => AlertDialog(
                                title: const Text('人设版本历史'),
                                content: SizedBox(
                                    width: 624,
                                    child: SingleChildScrollView(
                                        child: Column(
                                            children: (out['items'] as List)
                                                .map((v) => ListTile(
                                                    title: Text(
                                                        '${v['version_id']} · ${v['status']}'),
                                                    subtitle: Text('${v['change_summary']}'),
                                                    trailing: TextButton(
                                                        onPressed: () async {
                                                          Navigator.pop(ctx);
                                                          if (await confirm(
                                                              '回滚人设',
                                                              '回滚至 ${v['version_id']}？')) {
                                                            await api.request(
                                                                'POST',
                                                                '/persona/rollback',
                                                                {
                                                                  'id': v['id']
                                                                });
                                                          }
                                                        },
                                                        child: const Text('回滚'))))
                                                .toList()))),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('关闭'))
                                ]));
                  }),
              child: const Text('历史与回滚')),
          TextButton(
              onPressed: () => run(() async {
                    final out = await api.request('GET', '/persona/export');
                    await exportFile(
                        'persona.json',
                        const JsonEncoder.withIndent('  ')
                            .convert(out['json']));
                  }),
              child: const Text('导出人设文件')),
          TextButton(
              onPressed: () => run(() async {
                    final out = await api.request('GET', '/persona/export');
                    await exportFile('persona.md', out['markdown']);
                  }),
              child: const Text('导出 Markdown')),
          TextButton(
              onPressed: () => run(() async {
                    final out = await api.request('GET', '/persona/eval');
                    await exportFile(
                        'persona_eval_report.md', out['report_markdown']);
                  }),
              child: const Text('回归报告')),
          TextButton(
              onPressed: () => run(() async {
                    final out = await api.request('GET', '/traits');
                    await showDialog<void>(
                        context: navigatorKey.currentContext!,
                        builder: (ctx) => AlertDialog(
                                title: const Text('特征管理'),
                                content: SizedBox(
                                    width: 624,
                                    child: SingleChildScrollView(
                                        child: Column(
                                            children: (out['items'] as List)
                                                .map((t) => ListTile(
                                                    title: Text('${t['text']}'),
                                                    subtitle: Text(
                                                        '${t['layer']} · ${t['review_status']} · 来源 ${t['source_url']}'),
                                                    trailing: Wrap(children: [
                                                      IconButton(
                                                          icon: Icon(
                                                              t['paused'] ==
                                                                      true
                                                                  ? Icons
                                                                      .play_arrow
                                                                  : Icons
                                                                      .pause),
                                                          onPressed: () async {
                                                            Navigator.pop(ctx);
                                                            await api.request(
                                                                'PATCH',
                                                                "/traits/${t['id']}",
                                                                {
                                                                  'paused':
                                                                      t['paused'] !=
                                                                          true
                                                                });
                                                          }),
                                                      IconButton(
                                                          icon: const Icon(
                                                              Icons.edit),
                                                          onPressed: () async {
                                                            Navigator.pop(ctx);
                                                            final d = await edit(
                                                                '编辑特征 / 解决冲突', {
                                                              'text': t['text'],
                                                              'possible_conflicts':
                                                                  t['possible_conflicts']
                                                            });
                                                            if (d != null) {
                                                              await api.request(
                                                                  'PATCH',
                                                                  "/traits/${t['id']}",
                                                                  d);
                                                            }
                                                          }),
                                                      IconButton(
                                                          icon: const Icon(Icons
                                                              .delete_outline),
                                                          onPressed: () async {
                                                            Navigator.pop(ctx);
                                                            if (await confirm(
                                                                '删除特征',
                                                                '同时清除历史快照中的该特征？')) {
                                                              await api.request(
                                                                  'DELETE',
                                                                  "/traits/${t['id']}");
                                                            }
                                                          })
                                                    ])))
                                                .toList()))),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('关闭'))
                                ]));
                  }),
              child: const Text('暂停 / 编辑 / 删除')),
          TextButton(
              onPressed: () async {
                final d = await edit(
                    '比较版本 ID', {'left': '左侧记录 ID', 'right': '右侧记录 ID'});
                if (d != null) {
                  await run(() async {
                    await showData(
                        '人设差异',
                        await api.request('GET',
                            '/persona/diff?left=${Uri.encodeQueryComponent(d['left'])}&right=${Uri.encodeQueryComponent(d['right'])}'));
                  });
                }
              },
              child: const Text('比较版本')),
        ]),
        if (items.isEmpty) card('慢慢来', Text(PersonaAssets.empty('审核'))),
        ...items.map((r) => card(
            r['title'] ?? r['text'] ?? '待审核',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${RecordEditor.labelFor(r['layer'] ?? r['source_type'])}\n${r['source_url'] ?? ''}'),
              if (r['claims'] != null) Text(readableData(r['claims'])),
              Wrap(
                  children: ['approve', 'reject', 'defer', 'conflict']
                      .map((action) => TextButton(
                          onPressed: () => mutate('POST', '/review',
                              {'id': r['id'], 'action': action}),
                          child: Text({
                            'approve': '批准',
                            'reject': '拒绝',
                            'defer': '暂缓',
                            'conflict': '冲突'
                          }[action]!)))
                      .toList()),
              TextButton(
                  onPressed: () => run(() async {
                        await showData(
                            '静态示例预览',
                            await api.request('POST', '/persona/preview',
                                {'text': r['text'] ?? r['title']}));
                      }),
                  child: const Text('预览语气'))
            ])))
      ]);
  Widget sources() => ListView(children: [
        heading('来源搜索与导入', '搜索范围是已导入来源。自动平台搜索未授权；所有导入均进入待审核。'),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: search,
                  decoration: const InputDecoration(labelText: '关键词，如沈星回 性格'))),
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => run(() async {
                    payload = await api.request('GET',
                        '/sources?q=${Uri.encodeQueryComponent(search.text)}&exclude=${Uri.encodeQueryComponent(exclusion.text)}${platform == 'all' ? '' : '&platform=$platform'}');
                  }))
        ]),
        TextField(
            controller: exclusion,
            decoration: const InputDecoration(labelText: '排除关键词')),
        DropdownButton<String>(
            value: platform,
            items: ['all', 'manual', 'xiaohongshu', 'bilibili', 'public_web']
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => platform = v!)),
        FilledButton.tonal(
            onPressed: () => newRecord('URL / 授权文字导入', '/sources', {
                  'url': 'https://example.org/your-source',
                  'title': '填写标题',
                  'author': '填写作者',
                  'published_at': '填写发布时间',
                  'platform': 'manual',
                  'content_type': 'user_provided_text',
                  'source_version': '',
                  'text': '仅粘贴有权使用的必要文字，避免完整转载与私人信息'
                }),
            child: const Text('导入来源')),
        if (items.isEmpty) card('慢慢来', Text(PersonaAssets.empty('来源'))),
        ...items.map((r) => card(
            r['title'],
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${RecordEditor.labelFor(r['platform'])} · ${RecordEditor.labelFor(r['source_type'])}\n作者：${r['author']} · ${r['published_at']}\n${r['source_url']}'),
              TextButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(r['source_url']);
                    if (uri != null && uri.scheme == 'https') {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('打开原始链接')),
              TextButton(
                  onPressed: () async {
                    final d = await edit('人工标记来源', {
                      'source_type': r['source_type'],
                      'source_version': r['source_version'],
                      'evidence_status': r['evidence_status']
                    });
                    if (d != null) {
                      await mutate('PATCH', "/sources/${r['id']}", d);
                    }
                  },
                  child: const Text('标记官方 / 粉丝观点 / 不可靠')),
              TextButton(
                  onPressed: () => showData('声明与摘录', r['claims']),
                  child: const Text('查看事实声明 / 观点'))
            ])))
      ]);
  Widget memories() => ListView(children: [
        heading('他记得的事', '低置信度记录不参与检索；删除后不能继续检索。'),
        if (!connected)
          const Text('启动本地后端后，聊天与记忆将自动保存。双击 start_backend.bat，再到设置连接。'),
        if (items.isEmpty && connected) Text(PersonaAssets.empty('记忆')),
        FilledButton.tonal(
            onPressed: () => newRecord('明确记住这件事', '/memories', {
                  'kind': 'profile_memory',
                  'content': '我喜欢星空',
                  'consent': true,
                  'confidence': 1.0
                }),
            child: const Text('添加记忆')),
        ...items.map((r) => card(
            r['content'] ?? r['topic'] ?? '',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${RecordEditor.labelFor(r['kind'])} · ${r['review_status'] == 'approved' ? '已确认' : '待确认'}',
                  style: Theme.of(navigatorKey.currentContext!)
                      .textTheme
                      .bodySmall),
              Wrap(children: [
                TextButton(
                    onPressed: () async {
                      final d = await edit('修改记忆', {
                        'content': r['content'] ?? r['topic'],
                        'consent': true,
                        'confidence': r['confidence']
                      });
                      if (d != null) {
                        await mutate('PATCH', "/memories/${r['id']}", d);
                      }
                    },
                    child: const Text('编辑')),
                TextButton(
                    onPressed: () async {
                      if (await confirm('忘记这件事', '删除后不再检索这条记忆？')) {
                        await mutate('DELETE', "/memories/${r['id']}", {});
                      }
                    },
                    child: const Text('删除'))
              ])
            ])))
      ]);
  Widget rules() => ListView(children: [
        heading('一起相处，也一起改进', '资料搜寻、手动添加、相处记忆是独立规则。只提出候选，不自动改官方设定。'),
        if (api.baseUrl.isEmpty)
          card('需要本地长期记忆', const Text('规则引擎运行在后端。预览可体验聊天和外观；连接后端后再开启持续学习。')),
        ...items.map((r) => card(
            r['name'],
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['notice']),
              SwitchListTile(
                  title: const Text('启用此规则'),
                  value: r['enabled'] == true,
                  onChanged: (v) async {
                    if (v && r['rule_id'] == 'interaction_learning') {
                      if (!await confirm('允许从相处中提取候选',
                          '只分析已同意保存的非敏感对话。请先在设置开启保存聊天；提取结果需要你批准，才能成为长期记忆。')) {
                        return;
                      }
                    }
                    await mutate(
                        'PATCH', "/rules/${r['rule_id']}", {'enabled': v});
                  }),
              if (r['rule_id'] == 'persona_search')
                Wrap(children: [
                  TextButton(
                      onPressed: () async {
                        final d = await edit('搜索规则', {
                          'keywords': r['keywords'],
                          'exclude_keywords': r['exclude_keywords'],
                          'platforms': r['platforms']
                        });
                        if (d != null) {
                          await mutate('PATCH', "/rules/${r['rule_id']}", d);
                        }
                      },
                      child: const Text('关键词 / 排除 / 平台')),
                  TextButton(
                      onPressed: () => run(() async {
                            await showData(
                                '搜索任务状态',
                                await api.request(
                                    'POST', '/rules/persona_search/run'));
                          }),
                      child: const Text('创建搜寻任务'))
                ]),
              if (r['rule_id'] == 'manual_add')
                TextButton(
                    onPressed: () {
                      setState(() {
                        page = 4;
                        payload = {};
                      });
                      refresh();
                    },
                    child: const Text('去添加资料')),
            ]))),
        FilledButton.tonal(
            onPressed: () => run(() async {
                  final out = await api.request('GET', '/memory-candidates');
                  await showDialog<void>(
                      context: navigatorKey.currentContext!,
                      builder: (ctx) => AlertDialog(
                              title: const Text('相处记忆候选'),
                              content: SizedBox(
                                  width: 624,
                                  child: SingleChildScrollView(
                                      child: Column(
                                          children: (out['items'] as List)
                                              .map((c) => Card(
                                                  child: Padding(
                                                      padding: const EdgeInsets
                                                          .all(16),
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                '${c['content']}'),
                                                            Text(
                                                                "${c['memory_kind']} · 置信度 ${c['confidence']} · ${c['review_status']}\n理由：${c['reason']}\n到期：${c['expires_at']}"),
                                                            if (c['review_status'] ==
                                                                    'pending_review' ||
                                                                c['review_status'] ==
                                                                    'deferred')
                                                              Wrap(
                                                                  children: [
                                                                'approve',
                                                                'reject',
                                                                'defer'
                                                              ]
                                                                      .map((action) =>
                                                                          TextButton(
                                                                              onPressed:
                                                                                  () async {
                                                                                Navigator.pop(ctx);
                                                                                await api.request('POST', '/memory-candidates/review', {
                                                                                  'id': c['id'],
                                                                                  'action': action
                                                                                });
                                                                                notice(action == 'approve' ? '已确认进入长期记忆' : '候选状态已更新');
                                                                              },
                                                                              child: Text({
                                                                                'approve': '记住',
                                                                                'reject': '不要记',
                                                                                'defer': '稍后决定'
                                                                              }[action]!)))
                                                                      .toList()),
                                                          ]))))
                                              .toList()))),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('关闭'))
                              ]));
                }),
            child: const Text('审核相处记忆候选')),
        const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('只有你允许并确认的事，才会被记住。你随时可以修改或删除。')),
      ]);
  Widget design() => ListView(children: [
        heading('让这里成为你喜欢的样子', '主题、背景与界面参数可随时切换。背景只保存在应用设备，不上传本地。'),
        card(
            '动效质量',
            Wrap(
                spacing: 8,
                children: Appearance.qualities
                    .map((quality) => ChoiceChip(
                        label: Text(quality),
                        selected: appearance.quality == quality,
                        onSelected: (_) {
                          appearance.quality = quality;
                          saveAppearance();
                        }))
                    .toList())),
        card(
            '配色',
            Wrap(
                spacing: 8,
                children: Appearance.skins
                    .map((name) => ChoiceChip(
                        label: Text(name),
                        selected: appearance.skin == name,
                        onSelected: (_) {
                          appearance.skin = name;
                          saveAppearance();
                        }))
                    .toList())),
        card(
            '背景图库',
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Appearance.themes.keys
                    .map((name) => SizedBox(
                        width: ThemeConfig.number('gallery', 'tileWidth'),
                        child: InkWell(
                            onTap: () {
                              appearance.theme = name;
                              appearance.backgroundPath = null;
                              appearance.autoTheme = false;
                              appearance.skin =
                                  ThemeConfig.values['backgrounds'][name]
                                      ['skin'] as String;
                              saveAppearance();
                            },
                            child: Column(children: [
                              SizedBox(
                                  height: ThemeConfig.number(
                                      'gallery', 'tileHeight'),
                                  width: ThemeConfig.number(
                                      'gallery', 'tileWidth'),
                                  child: CustomPaint(
                                      painter: AmbientPainter(
                                          Appearance(
                                              theme: name,
                                              skin: appearance.skin),
                                          0))),
                              Text(
                                  '${appearance.backgroundPath == null && appearance.effectiveTheme == name ? '✓ ' : ''}$name')
                            ]))))
                    .toList())),
        SwitchListTile(
            title: const Text('跟随时间自动切换'),
            value: appearance.autoTheme,
            onChanged: (value) {
              appearance.autoTheme = value;
              if (value) appearance.backgroundPath = null;
              saveAppearance();
            }),
        SwitchListTile(
            title: const Text('动态背景'),
            subtitle: const Text('关闭可省电'),
            value: appearance.animated,
            onChanged: (value) {
              appearance.animated = value;
              saveAppearance();
            }),
        ...((ThemeConfig.values['plugins'] as Map<String, dynamic>).keys)
            .map((type) {
          final config = appearance.pluginConfig(type, rendering: false);
          void change(String key, dynamic value) {
            appearance.plugins[type] = <String, dynamic>{
              ...(appearance.plugins[type] as Map?)?.cast<String, dynamic>() ??
                  {},
              key: value
            };
            saveAppearance();
          }

          return card(
              config['label'] as String,
              Column(children: [
                SwitchListTile(
                    title: const Text('启用装饰'),
                    value: config['enabled'] == true,
                    onChanged: (v) => change('enabled', v)),
                Text('数量 ${(config['count'] as num).round()} · 当前显示 ${(appearance.pluginConfig(type)['count'] as num).round()}'),
                Slider(
                    value: (config['count'] as num).toDouble(),
                    min: 0,
                    max: (config['countMax'] as num).toDouble(),
                    divisions: (config['countMax'] as num).round(),
                    onChanged: (v) => change('count', v.round())),
                const Text('速度'),
                Slider(
                    value: (config['speed'] as num).toDouble(),
                    min: (config['speedMin'] as num).toDouble(),
                    max: (config['speedMax'] as num).toDouble(),
                    onChanged: (v) => change('speed', v)),
                const Text('透明度'),
                Slider(
                    value: (config['opacity'] as num).toDouble(),
                    onChanged: (v) => change('opacity', v)),
                const Text('大小'),
                Slider(
                    value: (config['size'] as num).toDouble(),
                    min: (config['sizeMin'] as num).toDouble(),
                    max: (config['sizeMax'] as num).toDouble(),
                    onChanged: (v) => change('size', v)),
              ]));
        }),
        card(
            '字体',
            DropdownButton<String>(
                value: appearance.font,
                items: Appearance.fonts
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                onChanged: (name) {
                  if (name != null) {
                    appearance.font = name;
                    saveAppearance();
                  }
                })),
        card(
            '自定义背景',
            Wrap(children: [
              FilledButton.tonalIcon(
                  onPressed: chooseBackground,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('从相册导入')),
              TextButton(
                  onPressed: () async {
                    appearance.backgroundPath = null;
                    await saveAppearance();
                  },
                  child: const Text('使用主题背景'))
            ])),
        if (gallery.isNotEmpty)
          card(
              '我的照片（长按删除）',
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: gallery
                      .map((photo) => InkWell(
                          onTap: () {
                            appearance.backgroundPath = photo.path;
                            appearance.autoTheme = false;
                            saveAppearance();
                          },
                          onLongPress: () async {
                            if (await confirm('删除这张背景', '只删除应用保存的副本，保留原照片。')) {
                              await BackgroundLibrary.delete(photo);
                              gallery.remove(photo);
                              await BackgroundLibrary.save(gallery);
                              if (appearance.backgroundPath == photo.path) {
                                appearance.backgroundPath = null;
                              }
                              await saveAppearance();
                            }
                          },
                          child: Column(children: [
                            Image.file(File(photo.thumbnail),
                                width:
                                    ThemeConfig.number('gallery', 'tileWidth'),
                                height:
                                    ThemeConfig.number('gallery', 'tileHeight'),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined)),
                            Text(appearance.backgroundPath == photo.path
                                ? '✓ 正在使用'
                                : '选择这张')
                          ])))
                      .toList())),
        card(
            '界面自定义',
            Column(children: [
              Text('背景遮罩 ${(appearance.overlay * 100).round()}%'),
              Slider(
                  value: appearance.overlay,
                  min: ThemeConfig.number('overlay', 'min'),
                  max: ThemeConfig.number('overlay', 'max'),
                  onChanged: (v) {
                    setState(() => appearance.overlay = v);
                  },
                  onChangeEnd: (_) => saveAppearance()),
              Text('卡片圆角 ${appearance.radius.round()}'),
              Slider(
                  value: appearance.radius,
                  min: ThemeConfig.number('radius', 'min'),
                  max: ThemeConfig.number('radius', 'max'),
                  onChanged: (v) => setState(() => appearance.radius = v),
                  onChangeEnd: (_) => saveAppearance()),
              Text('文字大小 ${appearance.textScale.toStringAsFixed(2)}'),
              Slider(
                  value: appearance.textScale,
                  min: ThemeConfig.number('textScale', 'min'),
                  max: ThemeConfig.number('textScale', 'max'),
                  onChanged: (v) => setState(() => appearance.textScale = v),
                  onChangeEnd: (_) => saveAppearance())
            ])),
        TextButton(
            onPressed: () async {
              final d = await edit(
                  '导入外观配置',
                  appearance.toJson()
                    ..remove('backgroundPath')
                    ..remove('plugins'));
              if (d != null) {
                final background = appearance.backgroundPath;
                final plugins = appearance.plugins;
                appearance = Appearance.fromJson(d);
                appearance.plugins = plugins;
                appearance.backgroundPath = background;
                await saveAppearance();
              }
            },
            child: const Text('编辑主题参数')),
        TextButton(
            onPressed: () => exportFile('appearance.json',
                jsonEncode(appearance.toJson()..remove('backgroundPath'))),
            child: const Text('导出主题参数'))
      ]);
  Widget character() => ListView(children: [
        heading('沈星回 · 逐光相伴', '深空猎人。住在六〇二。今天，也想和你待一会儿。'),
        card(
            '关于我',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (PersonaAssets.data['基础档案'] as Map<String, dynamic>)
                    .entries
                    .map((entry) => Text('${entry.key}：${entry.value}'))
                    .toList())),
        ...['外貌', '表层性格', '私下性格', '怪癖', '代表台词', '禁忌'].map((section) => card(
            section,
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (PersonaAssets.data[section] as List)
                    .map((value) => Text('$value'))
                    .toList()))),
        card(
            '情绪与相处',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (PersonaAssets.data['情绪场景表'] as List)
                    .map((row) => ListTile(
                        title: Text('${row['场景']}'),
                        subtitle: Text('${row['表现']} · ${row['言语与情绪特征']}')))
                    .toList())),
        card(
            '喜好与生活习惯',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (PersonaAssets.data['喜好与生活习惯']
                        as Map<String, dynamic>)
                    .entries
                    .map((entry) =>
                        Text('${entry.key}：${(entry.value as List).join('；')}'))
                    .toList())),
        Text(PersonaAssets.data['应用台词声明'] as String),
        const Text('资料来自你提供的人设报告；非官方应用。模型提示模板已预留，当前未接入模型。'),
      ]);
  Future<void> backupAll() async {
    await run(() async {
      final data = await PersonalBackup.export(api);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      await exportFile('xinghui-backup-$timestamp.json',
          const JsonEncoder.withIndent('  ').convert(data));
    });
  }

  Future<void> restoreAll() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = result?.files.single.path;
    if (path == null) return;
    if (!await confirm('恢复全部数据', '将替换本机聊天、记忆、打卡、热量、外观与提醒设置。建议先备份当前数据。')) return;
    await run(() async {
      final file = File(path);
      if (await file.length() > 128 * 1024 * 1024) {
        throw const FormatException('备份超过 128 MB');
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) throw const FormatException('备份格式无效');
      await PersonalBackup.restore(api, data);
      if (const bool.fromEnvironment('PERFORMANCE_PROBE')) {
        runApp(const PerformanceProbe());
        return;
      }
      await ReminderService.instance.load();
      try {
        await ReminderService.instance.reschedule();
      } catch (e) {
        notice('数据已恢复，提醒补排失败：$e');
      }
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('appearance');
      if (saved != null) appearance = Appearance.fromJson(jsonDecode(saved));
      gallery = await BackgroundLibrary.load();
      await avatars.load();
      messages.clear();
      notice('数据已恢复。');
    });
    await refresh();
  }

  Future<void> clearAll() async {
    await run(() async {
      await api.request('DELETE', '/data', {'confirmation': 'DELETE_ALL'});
      await HealthStore.instance.restore({
        'days': {},
        'customFoods': [],
        'weight': 0.0,
        'bmr': 0.0,
        'activityFactor': 1.2
      });
      final prefs = await SharedPreferences.getInstance();
      for (final photo in gallery) {
        await BackgroundLibrary.delete(photo);
      }
      gallery = [];
      for (final key in [
        'appearance',
        'background_gallery',
        'local_reminders',
        'weekly_backup_suggested'
      ]) {
        await prefs.remove(key);
      }
      appearance = Appearance();
      if (const bool.fromEnvironment('PERFORMANCE_PROBE')) {
        runApp(const PerformanceProbe());
        return;
      }
      await ReminderService.instance.load();
      try {
        await ReminderService.instance.reschedule();
      } catch (e) {
        notice('数据已清除，提醒取消失败：$e');
      }
      messages.clear();
    });
    await refresh();
  }

  Future<void> editHealthProfile() async {
    final store = HealthStore.instance;
    final weight = TextEditingController(
            text: store.weight > 0 ? '${store.weight}' : ''),
        bmr = TextEditingController(text: store.bmr > 0 ? '${store.bmr}' : ''),
        factor = TextEditingController(text: '${store.factor}');
    final values = await showDialog<List<double>>(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
                title: const Text('体重与每日目标'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: weight,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '体重（kg）')),
                  TextField(
                      controller: bmr,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '基础代谢（千卡 / 天，填写已知值）')),
                  TextField(
                      controller: factor,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: '活动系数（1–3，默认 1.2）')),
                  const Text('目标 = 基础代谢 × 活动系数；目标缺口 = 目标 − 今日净热量。')
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        final list = [
                          double.tryParse(weight.text),
                          double.tryParse(bmr.text),
                          double.tryParse(factor.text)
                        ];
                        if (list.every((n) => n != null && n.isFinite)) {
                          Navigator.pop(context, list.cast<double>());
                        }
                      },
                      child: const Text('保存'))
                ]));
    weight.dispose();
    bmr.dispose();
    factor.dispose();
    if (values == null) return;
    try {
      await store.profile(values[0], values[1], values[2]);
      if (mounted) setState(() {});
    } catch (e) {
      notice('$e');
    }
  }

  Widget preferences() => ListView(children: [
        Text('版本：${VersionStamp.current}'),
        card(
            '我的头像',
            Column(children: [
              if (avatars.path != null) Text('已使用本机保存的头像'),
              TextButton(
                  onPressed: () async {
                    try {
                      final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png']);
                      final path = picked?.files.single.path;
                      if (path == null) return;
                      await avatars.importFile(File(path));
                      if (mounted) setState(() {});
                      notice('头像已保存，可删除原图。');
                    } catch (e) {
                      notice('头像导入失败：$e');
                    }
                  },
                  child: const Text('上传我的头像')),
              TextButton(
                  onPressed: () async {
                    try {
                      await avatars.reset();
                      if (mounted) setState(() {});
                    } catch (e) {
                      notice('恢复头像失败：$e');
                    }
                  },
                  child: const Text('恢复默认头像'))
            ])),
        FilledButton(
            onPressed: busy ? null : connectLocal, child: const Text('连接本地后端')),
        const Text('双击 start_all.bat 一键启动；连接后聊天与记忆保存到这台电脑。'),
        if (BubbleConfig.error != null) Text(BubbleConfig.error!),
        card(
            '模型状态与聊天模式',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '供应商：${status['provider'] ?? '未连接'} · 模型：${status['model'] ?? '未配置'}'),
              Text(status['model_api_enabled'] == true
                  ? '模型调用已启用；Key仅在本地后端。'
                  : '当前未启用模型调用。'),
              DropdownButton<String>(
                  value: mode,
                  items: const [
                    DropdownMenuItem(value: 'chat', child: Text('陪伴')),
                    DropdownMenuItem(value: 'learning', child: Text('学习')),
                    DropdownMenuItem(
                        value: 'professional', child: Text('专业问答')),
                    DropdownMenuItem(value: 'research', child: Text('科研解释')),
                    DropdownMenuItem(value: 'code', child: Text('代码解释')),
                    DropdownMenuItem(value: 'paper', child: Text('论文阅读'))
                  ],
                  onChanged: (value) => setState(() => mode = value!)),
              if (status['model_api_enabled'] == true)
                SwitchListTile(
                    title: const Text('同意下一轮使用模型'),
                    subtitle: const Text('仅确认一次调用，发送后自动关闭；后端费用门禁保留。'),
                    value: confirmApi,
                    onChanged: (value) => setState(() => confirmApi = value)),
              const Text('草稿或消息长按／右键可复制、保存记忆、朗读、选择本轮保存方式。'),
            ])),
        card('每日提醒', const ReminderPanel()),
        card(
            '体重与热量目标',
            Column(children: [
              Text(
                  '体重 ${HealthStore.instance.weight} kg · 基础代谢 ${HealthStore.instance.bmr} · 活动系数 ${HealthStore.instance.factor}'),
              TextButton(
                  onPressed: editHealthProfile, child: const Text('填写体重与基础代谢'))
            ])),
        heading('设置与隐私', '这里填写应用访问令牌，不是模型 API Key。模型 Key 只在后端配置。'),
        ExpansionTile(title: const Text('手动连接设置'), children: [
          TextField(
              controller: url,
              decoration: const InputDecoration(
                  labelText: '本地后端地址 http://127.0.0.1:8080（留空为预览）')),
          const SizedBox(height: 16),
          TextField(
              controller: token,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: '应用访问令牌 AUTH_TOKEN')),
          FilledButton(
              onPressed: () async {
                api.baseUrl = url.text.trim();
                api.token = token.text.trim();
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('server_url', api.baseUrl);
                  await secure.write(key: 'access_token', value: api.token);
                  await refresh();
                } catch (e) {
                  notice('凭据安全保存失败：$e');
                }
              },
              child: const Text('保存并连接')),
        ]),
        card(
            '关于',
            const Text(
                '未启用模型时使用本地规则回复。人设依据你提供的报告，非官方应用。模型 Key 只在本机后端配置。\n内置字体使用 OFL 开源许可，许可证随包提供。语音功能尚未开放。\n食物来源：jhyan-ux/china-food-composition-data（OCR 数据，个人本地使用）。运动：Herrmann 等，2024 Adult Compendium，pacompendium.com；内置镜像 1111 条，非完整 1144 条。')),
        ...['save_conversations', 'emotion_enabled', 'voice_enabled']
            .map((key) => SwitchListTile(
                title: Text({
                  'save_conversations': '保存聊天（本地启动器默认开启）',
                  'emotion_enabled': '情绪候选判断',
                  'voice_enabled': '语音（目前模拟）',
                  'reminders_enabled': '提醒偏好（通知调度未接入）',
                  'reminders_paused': '暂停提醒'
                }[key]!),
                value: settings[key] == true,
                onChanged: (v) => mutate('PATCH', '/settings', {key: v}))),
        DropdownButton<String>(
            value: settings['language'] ?? 'zh-CN',
            items: ['zh-CN', 'en-US', 'ja-JP']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => mutate('PATCH', '/settings', {'language': v})),
        TextButton(
            onPressed: busy ? null : backupAll, child: const Text('一键备份全部数据')),
        TextButton(
            onPressed: busy ? null : restoreAll,
            child: const Text('从 JSON 恢复全部数据')),
        TextButton(
            onPressed: () async {
              if (await confirm(
                  '删除全部个人数据', '将清除当前本地数据库中的聊天、记忆、学习、打卡、人设版本与偏好。手动备份需另外删除。')) {
                await clearAll();
              }
            },
            child: const Text('删除全部个人数据')),
        const Text('离线时仅显示当前会话已有内容和外观设置；不排队发送，也不宣称具备本地大模型。')
      ]);
}
