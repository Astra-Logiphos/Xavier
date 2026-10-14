import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// JSON notation is YAML 1.2; the installed config takes precedence over assets.
class BubbleConfig {
  static Map<String, dynamic>? values;
  static String? error;
  static bool get loaded => values != null;
  static Future<void> load({File? file}) async {
    error = null;
    final external = file ??
        (Platform.isWindows
            ? File(
                '${File(Platform.resolvedExecutable).parent.path}/config/bubbles.yaml')
            : null);
    try {
      final text = external != null && external.existsSync()
          ? await external.readAsString()
          : await rootBundle.loadString('config/bubbles.yaml');
      values = parse(text);
    } catch (e) {
      error = '气泡配置读取失败：$e';
      values = parse(await rootBundle.loadString('config/bubbles.yaml'));
    }
  }

  static Map<String, dynamic> parse(String text) {
    final data =
        jsonDecode(text.replaceFirst('\uFEFF', '')) as Map<String, dynamic>;
    if (data['schema'] != 1 ||
        (data['skins'] as Map)[data['defaultSkin']] == null) {
      throw const FormatException('气泡皮肤结构无效');
    }
    final style =
        Map<String, dynamic>.from(data['skins'][data['defaultSkin']] as Map);
    if ((style['maxWidthFraction'] as num) <= 0 ||
        (style['maxWidthFraction'] as num) > 1 ||
        (style['avatar']['size'] as num) <= 0 ||
        (style['timestamp']['intervalMinutes'] as num) < 0) {
      throw const FormatException('气泡尺寸或时间间隔无效');
    }
    for (final key in ['userAlignment', 'companionAlignment']) {
      if (!['left', 'right'].contains(style[key])) {
        throw const FormatException('气泡方向须为left/right');
      }
    }
    if (style['userColor'] != 'derived') {
      final background = Color(int.parse(
          (style['userColor'] as String).replaceFirst('#', 'ff'),
          radix: 16));
      final foreground = Color(int.parse(
          (style['userText'] as String).replaceFirst('#', 'ff'),
          radix: 16));
      if (contrast(background, foreground) <
          (style['contrast']['minimum'] as num)) {
        throw const FormatException('指定气泡色与白字对比度不足，请选择更深的固定色');
      }
    }
    return data;
  }

  static Map<String, dynamic> get skin => Map<String, dynamic>.from(
      values!['skins'][values!['defaultSkin']] as Map);
  static double number(Map<String, dynamic> section, String key) =>
      (section[key] as num).toDouble();
  static Color color(
          String value, ThemeData theme, Color primary, Color text) =>
      switch (value) {
        'themePrimary' => primary,
        'themeText' => text,
        'themeSurface' => theme.colorScheme.surface,
        _ => Color(int.parse(value.replaceFirst('#', 'ff'), radix: 16)),
      };
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }

  static Color userColor(
      Color primary, Color foreground, Map<String, dynamic> style) {
    final explicit = style['userColor'] as String;
    if (explicit != 'derived') {
      return Color(int.parse(explicit.replaceFirst('#', 'ff'), radix: 16));
    }
    final source = HSLColor.fromColor(primary);
    final target = (style['contrast']['minimum'] as num).toDouble();
    if (contrast(primary, foreground) >= target) return primary;
    var low = 0.0, high = source.lightness;
    for (var i = 0; i < (style['contrast']['iterations'] as num).toInt(); i++) {
      final mid = (low + high) / 2;
      if (contrast(source.withLightness(mid).toColor(), foreground) >= target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return source.withLightness(low).toColor();
  }

  static TextStyle? textStyle(ThemeData theme, String name) => switch (name) {
        'bodySmall' => theme.textTheme.bodySmall,
        'titleLarge' => theme.textTheme.titleLarge,
        _ => theme.textTheme.bodyMedium,
      };
}
