import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/appearance.dart';
import 'package:xinghui_companion/avatar_store.dart';
import 'package:xinghui_companion/chat_page.dart';
import 'package:xinghui_companion/bubble_config.dart';
import 'package:xinghui_companion/connection_monitor.dart';
import 'package:xinghui_companion/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ThemeConfig.load();
    await BubbleConfig.load();
  });
  test('quality persists; half particles and low disables motion/blur', () {
    final a = Appearance();
    expect(a.pluginConfig('stars')['count'], 20);
    expect(a.pluginConfig('stars', rendering: false)['count'], 40);
    a.quality = '中';
    expect(a.pluginConfig('stars')['count'], 10);
    a.quality = '低';
    expect(a.pluginConfig('stars')['count'], 0);
    expect(a.motionEnabled, false);
    expect(a.blurEnabled, false);
    expect(Appearance.fromJson(a.toJson()).quality, '低');
    expect(Appearance.fromJson({'quality': 'invalid'}).quality, '高');
  });
  test('draft key stays stable after saved turn id arrives', () {
    final row = <String, dynamic>{'local_id': 'draft', 'user': 'hi'};
    final before = ChatMessage.fromTurns([row]).first.id;
    row['turn_id'] = 'saved';
    expect(ChatMessage.fromTurns([row]).first.id, before);
  });
  test('compressed avatar survives source deletion/reopen and resets',
      () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('xinghui-avatar-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/original.png');
    await source
        .writeAsBytes(img.encodePng(img.Image(width: 1000, height: 500)));
    final store = AvatarStore(installRoot: root);
    await store.importFile(source);
    final encoded = img.decodeJpg(await File(store.path!).readAsBytes())!;
    expect(encoded.width, 512);
    expect(encoded.height, 256);
    await source.delete();
    final reopened = AvatarStore(installRoot: root);
    await reopened.load();
    expect(reopened.path, store.path);
    expect(await File(reopened.path!).exists(), true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AvatarStore.preferenceKey), startsWith('avatar-'));
    await reopened.reset();
    await store.load();
    expect(store.path, isNull);
    expect(Directory('${root.path}/config/avatars').listSync(), isEmpty);
  });
  test('invalid avatar basename and corrupt image are rejected', () async {
    SharedPreferences.setMockInitialValues(
        {AvatarStore.preferenceKey: '../original.png'});
    final root = await Directory.systemTemp.createTemp('xinghui-avatar-');
    addTearDown(() => root.delete(recursive: true));
    final store = AvatarStore(installRoot: root);
    await store.load();
    expect(store.path, isNull);
    final invalid = File('${root.path}/invalid.png');
    await invalid.writeAsString('bad');
    await expectLater(store.importFile(invalid), throwsFormatException);
    expect(store.path, isNull);
  });
  testWidgets('40 typing updates and busy changes rebuild list zero times',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final rows = [
      <String, dynamic>{'local_id': '1', 'user': 'hello', 'reply': '嗯。'}
    ];
    Widget page(bool busy) => MaterialApp(
        home: Scaffold(
            body: ChatPage(
                messages: ChatMessage.fromTurns(rows),
                controller: controller,
                busy: busy,
                dark: false,
                primary: Colors.purple,
                textColor: Colors.black,
                emptyText: '',
                onSend: () {},
                onAction: (_, __) async {})));
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    final before = ChatPage.listBuilds;
    for (var i = 0; i < 40; i++) {
      await tester.enterText(
          find.byKey(const ValueKey('chat-input')), '星' * (i + 1));
      await tester.pump(const Duration(milliseconds: 35));
    }
    expect(ChatPage.listBuilds - before, 0, reason: 'typing only');
    await tester.pumpWidget(page(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ChatPage.listBuilds - before, 0);
    expect(controller.text.length, 40);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('health polling pauses hidden; business status never polled',
      (tester) async {
    final paths = <String>[];
    var resume = 0;
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:8080',
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response(jsonEncode({'ok': true}), 200);
        }));
    final monitor = ConnectionMonitor(api, (_) {}, () async {
      resume++;
    })
      ..start();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(paths, ['/health']);
    monitor.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 60));
    expect(paths.length, 1);
    monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resume, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(paths.length, 2);
    monitor.dispose();
    api.transport.close();
  });
}
