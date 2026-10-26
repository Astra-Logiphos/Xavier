/// 聊天记录导出（纯函数）：仅对话内容与时间戳。
/// 刻意排除系统提示词、persona 快照、token、emotion 内部方法等字段。
library;

const exportFormat = 'xinghui-chat-export';

List<Map<String, dynamic>> exportTurns(List<Map<String, dynamic>> rows) => [
      for (final row in rows)
        if (row['user'] != null && row['reply'] != null)
          {
            'time': row['assistant_time'] ?? row['created_at'] ?? row['utc_time'],
            'user': row['user'],
            'assistant': row['reply']
          }
    ];

Map<String, dynamic> exportPayload(List<Map<String, dynamic>> rows) {
  final turns = exportTurns(rows);
  return {
    'format': exportFormat,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'turn_count': turns.length,
    'turns': turns
  };
}

String exportMarkdown(List<Map<String, dynamic>> rows) {
  final payload = exportPayload(rows);
  final buffer = StringBuffer('# 星回聊天记录\n\n'
      '导出时间：${payload['exported_at']} · 共 ${payload['turn_count']} 轮\n\n'
      '仅含对话内容与时间戳。\n');
  for (final turn
      in (payload['turns'] as List<Map<String, dynamic>>)) {
    buffer
      ..writeln('\n---\n')
      ..writeln('**你**（${turn['time']}）：${turn['user']}\n')
      ..writeln('**星回**：${turn['assistant']}');
  }
  return buffer.toString();
}
