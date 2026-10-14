import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/bubble_config.dart';
import 'package:xinghui_companion/main.dart';
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/persona_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ThemeConfig.load();
    await BubbleConfig.load();
    await PersonaAssets.load();
  });
  void prepare(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://127.0.0.1:8080',
      'appearance': jsonEncode({'animated': false})
    });
    const storage =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => 'fixture');
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null));
  }

  testWidgets('ten mock sends retain history and clean chat layout',
      (tester) async {
    prepare(tester);
    var sent = 0;
    final client = MockClient((request) async {
      final result = switch (request.url.path) {
        '/status' => {'provider': 'mock', 'model_api_enabled': false},
        '/settings' => {'save_conversations': true},
        '/conversations' => {
            'items': [
              {
                'id': 'history',
                'user_text': '历史问候',
                'assistant_text': '我还在。',
                'created_at': '2026-10-14T01:00:00Z'
              }
            ]
          },
        '/chat' => {
            'reply': '模拟回复${++sent}',
            'saved': true,
            'turn_id': 'turn-$sent',
            'utc_time': DateTime.now().toUtc().toIso8601String()
          },
        _ => {'items': [], 'summary': {}, 'turns': []},
      };
      return http.Response(jsonEncode(result), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(XinghuiApp(client: ApiClient(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天').first);
    await tester.pumpAndSettle();
    expect(find.text('历史问候'), findsOneWidget);
    expect(find.text('本地已连接'), findsOneWidget);
    for (var i = 1; i <= 10; i++) {
      await tester.enterText(find.byKey(const ValueKey('chat-input')), '第$i条');
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
    }
    expect(sent, 10);
    await tester.scrollUntilVisible(find.text('模拟回复10'), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('chat-list')),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('模拟回复10'), findsOneWidget);
    for (final name in ['本轮不保存', '同意保存学习记录', '同意本轮使用模型', '修正情绪']) {
      expect(find.text(name), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('API confirmation belongs to settings and is consumed once',
      (tester) async {
    prepare(tester);
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final result = switch (request.url.path) {
        '/status' => {
            'provider': 'zhipu',
            'model': 'fixture-model',
            'model_api_enabled': true
          },
        '/settings' => {'save_conversations': true},
        '/conversations' => {'items': []},
        '/chat' => {'reply': '模拟回答', 'saved': true, 'turn_id': 'fixture'},
        _ => {'items': [], 'summary': {}, 'turns': []},
      };
      if (request.url.path == '/chat') bodies.add(jsonDecode(request.body));
      return http.Response(jsonEncode(result), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(XinghuiApp(client: ApiClient(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('同意下一轮使用模型'));
    await tester.tap(find.text('同意下一轮使用模型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '一次确认');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(bodies.single['api_confirmed'], true);
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    final control = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '同意下一轮使用模型'));
    expect(control.value, false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('pending turn unsave is applied after the response',
      (tester) async {
    prepare(tester);
    final response = Completer<http.Response>();
    var deleted = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/chat') return response.future;
      if (request.method == 'DELETE') {
        deleted++;
        return http.Response('{"deleted":true}', 200);
      }
      final result = switch (request.url.path) {
        '/status' => {'provider': 'mock'},
        '/settings' => {'save_conversations': true},
        '/conversations' => {'items': []},
        _ => {'summary': {}, 'turns': [], 'items': []}
      };
      return http.Response(jsonEncode(result), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(XinghuiApp(client: ApiClient(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '发送中的这一轮');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.text('发送中的这一轮'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('本轮不保存'));
    await tester.pump(const Duration(milliseconds: 300));
    response.complete(http.Response(
        jsonEncode({'reply': '模拟回答', 'saved': true, 'turn_id': 'pending'}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
