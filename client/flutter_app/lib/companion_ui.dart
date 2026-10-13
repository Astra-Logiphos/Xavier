import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'persona_assets.dart';

String readableText(dynamic value) {
  if (value is String) return value;
  if (value is Map) return readableText(value['text'] ?? value['content'] ?? value['topic']);
  return '';
}
String dailyNarrative(Map<String, dynamic> summary) {
  final lines = <String>[];
  for (final entry in {'learned': '今天一起学了', 'events': '记下了这些事',
      'promises_and_todos': '还想一起完成', 'unfinished_topics': '下次可以接着聊'}.entries) {
    final values = (summary[entry.key] as List? ?? []).map(readableText).where((text) => text.isNotEmpty).toList();
    if (values.isNotEmpty) lines.add('${entry.value}：${values.join('；')}。');
  }
  if (lines.isEmpty && (summary['chat_topics'] as List? ?? []).isNotEmpty) {
    lines.add('今天留下了 ${(summary['chat_topics'] as List).length} 个聊天片段。慢慢说的事，都有了位置。');
  }
  return lines.isEmpty ? PersonaAssets.empty('今日') : lines.join('\n\n');
}
String readableData(dynamic value) {
  if (value is Map) return value.entries.map((entry) => '${entry.key}：${readableData(entry.value)}').join('\n');
  if (value is List) return value.map(readableData).join('\n');
  return value == null ? '暂无' : '$value';
}

class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: ThemeConfig.number('hero', 'width'), height: ThemeConfig.number('hero', 'height'),
    child: CustomPaint(painter: _PortraitPainter()));
}
class _PortraitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final config = ThemeConfig.values['hero'];
    for (final shape in config['shapes'] as List) {
      final hex = config['colors'][shape['color']] as String;
      final paint = Paint()..color = Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
      if (shape['kind'] == 'oval') {
        final r = (shape['rect'] as List).cast<num>();
        canvas.drawOval(Rect.fromLTRB(r[0] * size.width, r[1] * size.height, r[2] * size.width, r[3] * size.height), paint);
      } else {
        final path = Path();
        for (final command in shape['points'] as List) {
          switch (command[0]) {
            case 'M': path.moveTo(command[1] * size.width, command[2] * size.height);
            case 'L': path.lineTo(command[1] * size.width, command[2] * size.height);
            case 'Q': path.quadraticBezierTo(command[1] * size.width, command[2] * size.height, command[3] * size.width, command[4] * size.height);
            case 'Z': path.close();
          }
        }
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
