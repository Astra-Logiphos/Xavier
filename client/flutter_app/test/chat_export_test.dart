import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/chat_export.dart';

void main() {
  final rows = [
    {
      'user': '今天有点累',
      'reply': '先坐一会儿。',
      'saved': true,
      'created_at': '2026-10-24T12:00:00Z'
    },
    {
      'user': '吃的什么',
      'reply': '肉。',
      'saved': true,
      'assistant_time': '2026-10-24T12:05:00Z',
      'emotion': {'label': 'happy', 'method': 'keyword_candidate'},
      'turn_id': 'internal-id'
    },
    {'user': '未保存草稿', 'reply': null, 'saved': false},
  ];

  test('only saved turns with both sides are exported', () {
    final payload = exportPayload(rows);
    expect(payload['format'], 'xinghui-chat-export');
    expect(payload['turn_count'], 2);
    expect(payload['turns'][0]['user'], '今天有点累');
    expect(payload['turns'][1]['time'], '2026-10-24T12:05:00Z');
  });

  test('export carries no persona, prompt or internal fields', () {
    final text = const JsonEncoder.withIndent(' ').convert(exportPayload(rows));
    for (final banned in ['emotion', 'turn_id', 'saved', 'persona', 'prompt',
        'core_snapshot', 'token']) {
      expect(text.contains(banned), isFalse, reason: banned);
    }
  });

  test('markdown lists each turn with timestamp, user and companion lines', () {
    final markdown = exportMarkdown(rows);
    expect(markdown, contains('共 2 轮'));
    expect(markdown, contains('**你**（2026-10-24T12:00:00Z）：今天有点累'));
    expect(markdown, contains('**星回**：肉。'));
    expect(markdown, contains('---'));
  });
}
