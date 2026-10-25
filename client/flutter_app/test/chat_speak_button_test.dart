import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinghui_companion/bubble_config.dart';
import 'package:xinghui_companion/chat_page.dart';
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/persona_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ThemeConfig.load();
    await BubbleConfig.load();
    await PersonaAssets.load();
  });
  final messages = [
    ChatMessage(
        id: 't1',
        role: 'user',
        text: '你好',
        time: DateTime(2026, 10, 24, 9),
        turn: const {}),
    ChatMessage(
        id: 't1-companion',
        role: 'companion',
        text: '嗯，来了。',
        time: DateTime(2026, 10, 24, 9),
        turn: const {'emotion': {'label': 'calm'}})
  ];
  Widget page({required bool voiceEnabled}) => MaterialApp(
          home: Scaffold(
              body: ChatPage(
                  voiceEnabled: voiceEnabled,
                  messages: messages,
                  controller: TextEditingController(),
                  busy: false,
                  dark: false,
                  primary: const Color(0xFF5B7FD3),
                  textColor: Colors.black,
                  emptyText: '空',
                  onSend: () {},
                  onAction: (action, selected) async {})));
  testWidgets('speak button appears on companion bubbles only when enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(page(voiceEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('speak-t1-companion')), findsOneWidget);
    expect(find.byKey(const ValueKey('speak-t1-user')), findsNothing);
    await tester.pumpWidget(page(voiceEnabled: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('speak-t1-companion')), findsNothing);
  });
}
