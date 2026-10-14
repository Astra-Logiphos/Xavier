import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/appearance.dart';
import 'package:xinghui_companion/bubble_config.dart';
import 'package:xinghui_companion/chat_page.dart';
import 'package:xinghui_companion/theme_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ThemeConfig.load();
    await BubbleConfig.load();
  });
  setUp(() async {
    await BubbleConfig.load();
  });
  ChatMessage entry(String id, String role, DateTime time, String text) =>
      ChatMessage(id: id, role: role, text: text, time: time, turn: {});
  final first = DateTime(2026, 10, 14, 9);
  test('five minutes strictly and same-side avatar grouping', () {
    final a = entry('a', 'user', first, '一'),
        b = entry('b', 'user', first.add(const Duration(minutes: 5)), '二'),
        c = entry('c', 'user',
            first.add(const Duration(minutes: 5, seconds: 1)), '三');
    expect(ChatPage.timestampBefore(a, null, BubbleConfig.skin), isTrue);
    expect(ChatPage.timestampBefore(b, a, BubbleConfig.skin), isFalse);
    expect(ChatPage.timestampBefore(c, a, BubbleConfig.skin), isTrue);
  });
  test('derived color preserves hue saturation and white contrast', () {
    for (final hex in ['#6E9BD8', '#8B7EC8']) {
      final seed = Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
      final source = HSLColor.fromColor(seed);
      final color =
              BubbleConfig.userColor(seed, Colors.white, BubbleConfig.skin),
          hsl = HSLColor.fromColor(color);
      expect(BubbleConfig.contrast(color, Colors.white),
          greaterThanOrEqualTo(4.5));
      expect(hsl.hue, closeTo(source.hue, 1));
      expect(hsl.saturation, closeTo(source.saturation, .02));
    }
  });
  test('fixed color override and canonical resource match', () async {
    final style = Map<String, dynamic>.from(BubbleConfig.skin)
      ..['userColor'] = '#6A4EA1';
    expect(BubbleConfig.userColor(Colors.blue, Colors.white, style),
        const Color(0xff6A4EA1));
    expect(await rootBundle.loadString('config/bubbles.yaml'),
        File('../../config/bubbles.yaml').readAsStringSync());
  });
  testWidgets('external config changes survive reload', (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('bubbles');
      try {
        final data =
            jsonDecode(await rootBundle.loadString('config/bubbles.yaml'));
        data['skins'][data['defaultSkin']]['companionLightColor'] = '#E5DCF6';
        final file = File('${directory.path}/bubbles.yaml');
        await file.writeAsString(jsonEncode(data));
        await BubbleConfig.load(file: file);
        expect(BubbleConfig.skin['companionLightColor'], '#E5DCF6');
        await BubbleConfig.load(file: file);
        expect(BubbleConfig.skin['companionLightColor'], '#E5DCF6');
      } finally {
        await directory.delete(recursive: true);
        await BubbleConfig.load();
      }
    });
  });
  testWidgets('sides, outside avatars, width, timestamp grouping and menu',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final actions = <String>[];
    final rows = [
      entry('a', 'companion', first, '早。'),
      entry('b', 'companion', first.add(const Duration(minutes: 1)), '慢慢说。'),
      entry('c', 'user', first.add(const Duration(minutes: 2)), '你好。'),
      entry('d', 'user', first.add(const Duration(minutes: 8)), '过了六分钟。')
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChatPage(
                messages: rows,
                controller: controller,
                busy: false,
                dark: false,
                primary: const Color(0xff6E9BD8),
                textColor: const Color(0xff423A5E),
                emptyText: '我在。',
                onSend: () {},
                onAction: (action, row) async {
                  actions.add(action);
                }))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-companion')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-user')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('timestamp-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('timestamp-b')), findsNothing);
    expect(find.byKey(const ValueKey('timestamp-d')), findsOneWidget);
    final left = tester.getRect(find.byKey(const ValueKey('bubble-a'))),
        right = tester.getRect(find.byKey(const ValueKey('bubble-c')));
    expect(left.left, lessThan(right.left));
    expect(left.width, lessThanOrEqualTo(700));
    final avatars =
        tester.getRect(find.byKey(const ValueKey('avatar-companion')));
    expect(avatars.width, 40);
    expect(avatars.right, lessThan(left.left));
    await tester.longPress(find.byKey(const ValueKey('bubble-c')));
    await tester.pumpAndSettle();
    for (final name in ['复制', '保存到记忆', '朗读', '本轮不保存', '同意保存学习记录']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(actions, ['copy']);
  });
  testWidgets('light and dark render screenshots without flow controls',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    for (final dark in [false, true]) {
      final key = GlobalKey();
      final rows = [
        entry('a', 'companion', first, '嗯，我在。'),
        entry(
            'b', 'user', first.add(const Duration(minutes: 1)), '今天也想和你聊一会儿。'),
        entry('c', 'companion', first.add(const Duration(minutes: 2)), '慢慢说。')
      ];
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              theme: Appearance().materialTheme,
              home: Scaffold(
                  body: ChatPage(
                      messages: rows,
                      controller: controller,
                      busy: false,
                      dark: dark,
                      primary: const Color(0xff6E9BD8),
                      textColor: const Color(0xff423A5E),
                      emptyText: '我在。',
                      onSend: () {},
                      onAction: (a, b) async {})))));
      await tester.pumpAndSettle();
      for (final hidden in [
        '本轮不保存',
        '同意保存学习记录',
        '同意本轮使用模型',
        '修正情绪',
        '已经记下这段对话'
      ]) {
        expect(find.text(hidden), findsNothing);
      }
      final bubble =
          tester.widget<Container>(find.byKey(const ValueKey('bubble-a')));
      expect((bubble.decoration as BoxDecoration).color,
          dark ? const Color(0xff2F2F2F) : Colors.white);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image =
          await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      final bytes = await tester
          .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      final directory = Directory('../../runtime/ui-checks')
        ..createSync(recursive: true);
      File('${directory.path}/m15-chat-${dark ? 'dark' : 'light'}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image!.dispose();
    }
  });
}
