import 'package:flutter/material.dart';

/// 情绪时间线（纯 Flutter 画布）：最近 7 天情绪分布，不加重型依赖。
/// 数据来源：/api/chat 已返回并保存在消息行里的 emotion.label + 时间戳。
const emotionColors = <String, Color>{
  'happy': Color(0xFF7BAF7B),
  'excited': Color(0xFFD9A441),
  'calm': Color(0xFF6FA3C7),
  'neutral': Color(0xFF9AA0A6),
  'sad': Color(0xFF6B7FB0),
  'anxious': Color(0xFFB0788C),
  'tired': Color(0xFF8B8B9E)
};

Map<String, int> emotionCounts(List<Map<String, dynamic>> rows,
    {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final counts = <String, int>{};
  for (final row in rows) {
    final emotion = row['emotion'];
    if (emotion is! Map || emotion['label'] is! String) continue;
    final time = DateTime.tryParse('${row['assistant_time'] ?? row['created_at'] ?? ''}')
        ?.toLocal();
    if (time == null) continue;
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(time.year, time.month, time.day))
        .inDays;
    if (days < 0 || days > 6) continue;
    counts[emotion['label'] as String] = (counts[emotion['label'] as String] ?? 0) + 1;
  }
  return counts;
}

class EmotionTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const EmotionTimeline({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final counts = emotionCounts(rows);
    final total = counts.values.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('最近 7 天情绪分布（来自已保存对话）',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      if (total == 0)
        const Text('最近 7 天还没有带情绪标注的已保存对话。')
      else ...[
        SizedBox(
            height: 96,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in counts.entries)
                    Expanded(
                        child: Tooltip(
                            message: '${entry.key} × ${entry.value}',
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: FractionallySizedBox(
                                    heightFactor:
                                        (entry.value / total).clamp(0.08, 1.0),
                                    child: Container(
                                        alignment: Alignment.topCenter,
                                        decoration: BoxDecoration(
                                            color: emotionColors[entry.key] ??
                                                Colors.grey,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(6))),
                                        child: Text('${entry.value}',
                                            style: const TextStyle(
                                                fontSize: 11))))))
                ])),
        const SizedBox(height: 6),
        Wrap(
            spacing: 10,
            children: [
              for (final entry in counts.entries)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 10,
                      height: 10,
                      color: emotionColors[entry.key] ?? Colors.grey),
                  const SizedBox(width: 4),
                  Text('${entry.key} ${entry.value}',
                      style: Theme.of(context).textTheme.bodySmall)
                ])
            ])
      ]
    ]);
  }
}
