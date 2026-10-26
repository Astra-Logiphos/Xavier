import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/emotion_timeline.dart';

void main() {
  final now = DateTime(2026, 10, 25, 12);
  Map<String, dynamic> row(int daysAgo, String label) => {
        'emotion': {'label': label},
        'created_at': now.subtract(Duration(days: daysAgo)).toUtc().toIso8601String()
      };

  test('counts only emotions within last 7 days', () {
    final counts = emotionCounts([
      row(0, 'happy'),
      row(1, 'happy'),
      row(2, 'sad'),
      row(9, 'calm'), // 超出 7 天窗口
      {'emotion': null}, // 无标注
      {'emotion': {'label': 'happy'}}, // 无时间戳
    ], now: now);
    expect(counts, {'happy': 2, 'sad': 1});
  });

  testWidgets('renders bars and legend for recorded emotions', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EmotionTimeline(rows: [
      row(0, 'happy'),
      row(1, 'sad'),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('happy 1'), findsOneWidget);
    expect(find.text('sad 1'), findsOneWidget);
    expect(find.byType(Tooltip), findsNWidgets(2));
  });

  testWidgets('shows empty hint when nothing is in range', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EmotionTimeline(rows: [row(9, 'calm')]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有带情绪标注'), findsOneWidget);
  });
}
