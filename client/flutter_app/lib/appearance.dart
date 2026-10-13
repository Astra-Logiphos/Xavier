import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'package:google_fonts/google_fonts.dart';

class Appearance {
  String theme;
  String font;
  String? backgroundPath;
  double overlay;
  double radius;
  double textScale;
  Appearance({String? theme, String? font, this.backgroundPath, double? overlay,
    double? radius, double? textScale})
      : font = font ?? ThemeConfig.values['defaultFont'] as String,
        theme = theme ?? ThemeConfig.values['defaultTheme'] as String,
        overlay = overlay ?? ThemeConfig.number('overlay', 'default'),
        radius = radius ?? ThemeConfig.number('radius', 'default'),
        textScale = textScale ?? ThemeConfig.number('textScale', 'default');
  static Map<String, Color> get themes =>
      (ThemeConfig.values['themes'] as Map<String, dynamic>).map((key, value) =>
        MapEntry(key, Color(int.parse((value as String).replaceFirst('#', 'ff'), radix: 16))));
  bool get dark => theme == ThemeConfig.values['darkTheme'];
  static List<String> get fonts => (ThemeConfig.values['fonts'] as Map<String, dynamic>).keys.toList();
  TextTheme get textTheme {
    final common = TextStyle(height: ThemeConfig.number('text', 'height'),
      fontWeight: FontWeight.values[(ThemeConfig.number('text', 'weight') / 100).round() - 1]);
    final title = common.copyWith(fontSize: ThemeConfig.number('text', 'headingSize'));
    final body = common.copyWith(fontSize: ThemeConfig.number('text', 'bodySize'));
    final auxiliary = common.copyWith(fontSize: ThemeConfig.number('text', 'auxiliarySize'));
    final basic = TextTheme(displayLarge: title, displayMedium: title, displaySmall: title,
      headlineLarge: title, headlineMedium: title, headlineSmall: title,
      titleLarge: title, titleMedium: title, titleSmall: title,
      bodyLarge: body, bodyMedium: body, bodySmall: auxiliary,
      labelLarge: body, labelMedium: auxiliary, labelSmall: auxiliary);
    final family = ThemeConfig.values['fonts'][font] as String?;
    if (family == null) return basic;
    GoogleFonts.config.allowRuntimeFetching = false;
    return GoogleFonts.getTextTheme(family, basic);
  }
  ThemeData get materialTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: themes[theme] ?? themes[ThemeConfig.values['defaultTheme']]!,
      brightness: dark ? Brightness.dark : Brightness.light),
    textTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius))),
    cardTheme: CardThemeData(shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius))),
  );
  Map<String, dynamic> toJson() => {'theme': theme, 'font': font, 'backgroundPath': backgroundPath,
    'overlay': overlay, 'radius': radius, 'textScale': textScale};
  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
    theme: themes.containsKey(json['theme']) ? json['theme'] as String : ThemeConfig.values['defaultTheme'] as String,
    font: fonts.contains(json['font']) ? json['font'] as String : ThemeConfig.values['defaultFont'] as String,
    backgroundPath: json['backgroundPath'] as String?,
    overlay: (json['overlay'] as num? ?? ThemeConfig.number('overlay', 'default')).toDouble().clamp(ThemeConfig.number('overlay', 'min'), ThemeConfig.number('overlay', 'max')),
    radius: (json['radius'] as num? ?? ThemeConfig.number('radius', 'default')).toDouble().clamp(ThemeConfig.number('radius', 'min'), ThemeConfig.number('radius', 'max')),
    textScale: (json['textScale'] as num? ?? ThemeConfig.number('textScale', 'default')).toDouble().clamp(ThemeConfig.number('textScale', 'min'), ThemeConfig.number('textScale', 'max')));
}
