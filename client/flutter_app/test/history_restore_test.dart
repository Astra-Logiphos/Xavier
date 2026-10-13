import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/main.dart';
import 'package:xinghui_companion/theme_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ThemeConfig.load);
  testWidgets('disconnected saved endpoint shows local startup instructions', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'server_url': 'http://127.0.0.1:8080'});
    const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage, (_) async => 'test-token');
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage, null));
    final client = MockClient((_) async => throw Exception('backend offline'));
    await tester.pumpWidget(XinghuiApp(client: ApiClient(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('本地后端未连接'), findsOneWidget);
    expect(find.textContaining('启动本地后端后，聊天与记忆将自动保存'), findsOneWidget);
  });
  testWidgets('reopened app restores saved conversation and memory page', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'server_url': 'http://127.0.0.1:8080'});
    const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage, (_) async => 'test-token');
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage, null));
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      final result = switch (request.url.path) {
        '/status' => {'persona_version': 'test'},
        '/settings' => {'save_conversations': true},
        '/daily' => {'turns': [], 'summary': {}},
        '/conversations' => {'items': [{'user_text': '保存的问候', 'assistant_text': '我在这里', 'id': 'turn-1', 'emotion': {}}]},
        '/memories' => {'items': [{'id': 'memory-1', 'content': '我喜欢星空', 'kind': 'profile_memory', 'confidence': 1.0, 'consent': true}]},
        _ => <String, dynamic>{},
      };
      return http.Response(jsonEncode(result), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    for (var reopen = 0; reopen < 2; reopen++) {
      await tester.pumpWidget(XinghuiApp(client: ApiClient(client: client)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('聊天'));
      await tester.pumpAndSettle();
      expect(find.text('你：保存的问候'), findsOneWidget);
      expect(find.text('我在这里'), findsOneWidget);
      await tester.tap(find.text('记忆'));
      await tester.pumpAndSettle();
      expect(find.text('他记得的事'), findsOneWidget);
      expect(find.text('我喜欢星空'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
