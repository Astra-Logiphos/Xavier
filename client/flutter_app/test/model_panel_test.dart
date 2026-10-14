import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/model_panel.dart';

void main() {
  testWidgets('wizard tests before save and clears transient key after save',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:8080',
        token: 'fixture',
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
                jsonEncode({
                  'provider': 'zhipu',
                  'api_enabled': false,
                  'providers': [
                    {
                      'provider': 'zhipu',
                      'label': '智谱',
                      'base_url': 'https://fixture.invalid',
                      'saved_base_url': 'https://fixture.invalid',
                      'models': ['fixture-model'],
                      'saved_model': 'fixture-model',
                      'free_models': ['fixture-model'],
                      'key_configured': false,
                      'hint': 'fixture'
                    },
                    {
                      'provider': 'deepseek',
                      'label': 'DeepSeek',
                      'base_url': 'https://paid.invalid',
                      'saved_base_url': 'https://paid.invalid',
                      'models': ['paid'],
                      'saved_model': 'paid',
                      'free_models': [],
                      'key_configured': true,
                      'hint': 'fixture'
                    }
                  ]
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          requests.add({
            'path': r.url.path,
            ...jsonDecode(r.body) as Map<String, dynamic>
          });
          return http.Response(jsonEncode({'ok': true, 'saved': true}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ModelPanel(api: api, onSaved: () async {})))));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '6 · 保存到本机后端');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
        find.byKey(const ValueKey('model-key')), 'fixture-transient-key');
    await tester.ensureVisible(find.text('4 · 测试连接'));
    await tester.tap(find.text('4 · 测试连接'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(requests.single['path'], '/model/test');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(requests.last['path'], '/model/config');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('model-key')))
            .controller!
            .text,
        isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('model-provider')));
    await tester.tap(find.byKey(const ValueKey('model-provider')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepSeek').last);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(find.text('明确同意此模型可能产生费用'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    final key =
        tester.widget<TextField>(find.byKey(const ValueKey('model-key')));
    expect(key.controller!.text, isEmpty);
    expect(key.decoration!.hintText, contains('留空保留原Key'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'missing model configuration shows recovery wording, never type error',
      (tester) async {
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:8080',
        client: MockClient((r) async => http.Response('{}', 200)));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ModelPanel(api: api, onSaved: () async {}))));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(find.text('本地模型配置暂不可用，请应用补丁并重启后端。'), findsOneWidget);
    expect(find.textContaining('not a subtype'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
