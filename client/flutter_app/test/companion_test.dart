import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/companion_controller.dart';
import 'package:xinghui_companion/chat_page.dart';
import 'package:xinghui_companion/bubble_config.dart';
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/persona_assets.dart';
import 'package:xinghui_companion/local_voice_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ThemeConfig.load();
    await BubbleConfig.load();
    await PersonaAssets.load();
  });
  test('offline card mirror is byte-identical to sole backend source',
      () async {
    final source = await File('../../config/persona_v1_1.json').readAsBytes();
    final mirror = await File('assets/persona/persona_v1_1.json').readAsBytes();
    expect(mirror, source);
    expect(PersonaAssets.core['display']['角色年龄'], '23岁');
    expect(PersonaAssets.core['display']['生日'], contains('10月16日'));
  });
  testWidgets('companion timers pause hidden and never poll business status',
      (tester) async {
    final requests = <String>[];
    final events = <Map<String, dynamic>>[];
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:8080',
        client: MockClient((r) async {
          requests.add(r.url.path);
          final value = r.method == 'GET'
              ? {'tick_seconds': 60}
              : {
                  'events': [
                    {'type': 'greeting', 'text': 'fixture'}
                  ]
                };
          return http.Response(jsonEncode(value), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final controller = CompanionController(api, events.addAll);
    await tester.runAsync(controller.start);
    expect(requests, ['/companion/config', '/companion/tick']);
    expect(events, hasLength(1));
    controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump(const Duration(minutes: 5));
    expect(requests, hasLength(2));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    expect(requests, hasLength(3));
    expect(requests, isNot(contains('/status')));
    controller.dispose();
    api.transport.close();
  });
  testWidgets(
      'saved proactive event shows one companion bubble, no empty user bubble',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final messages = ChatMessage.fromTurns([
      {'local_id': 'event', 'assistant_only': true, 'reply': '嗯，醒了。'}
    ]);
    expect(messages, hasLength(1));
    expect(messages.single.role, 'companion');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChatPage(
                messages: messages,
                controller: controller,
                busy: false,
                dark: false,
                primary: Colors.purple,
                textColor: Colors.black,
                emptyText: '',
                onSend: () {},
                onAction: (_, __) async {}))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-companion')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-user')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
      'local voice manifest rejects URL and traversal without external playback',
      () async {
    final root =
        await Directory.systemTemp.createTemp('xinghui-voice-fixture-');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory('${root.path}/assets/voices');
    await directory.create(recursive: true);
    final manifest = File('${directory.path}/manifest.json');
    for (final path in [
      '../outside.wav',
      'https://fixture.invalid/file.wav',
      'C:/outside.wav'
    ]) {
      await manifest.writeAsString(jsonEncode({
        'greeting_morning': [path]
      }));
      expect(await LocalVoicePack.play('greeting_morning', installRoot: root),
          false);
    }
  });
  test(
      'history refresh retains concurrent event once, removes genuinely deleted saved rows',
      () {
    final local = <Map<String, dynamic>>[
      {'turn_id': 'deleted', 'saved': true, 'reply': 'old'},
      {
        'turn_id': 'new',
        'saved': true,
        'assistant_only': true,
        'reply': 'new',
        'event_sequence': 2
      },
      {'local_id': 'draft', 'saved': false, 'user': 'draft'}
    ];
    final result = ChatMessage.mergeHistory(local, [], 1);
    expect(result.map((row) => row['turn_id']), isNot(contains('deleted')));
    expect(result.any((row) => row['turn_id'] == 'new'), true);
    final synced = ChatMessage.mergeHistory(
        local,
        [
          {'id': 'new', 'assistant_text': 'new', 'assistant_only': true}
        ],
        1);
    expect(synced.where((row) => row['turn_id'] == 'new'), hasLength(1));
    expect(synced.last['local_id'], 'draft');
  });
}
