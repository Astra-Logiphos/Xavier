import 'package:flutter/material.dart';
import 'theme_config.dart';

class Appearance {
  String theme;
  String? backgroundPath;
  double overlay;
  double radius;
  double textScale;
  Appearance({String? theme, this.backgroundPath, double? overlay,
    double? radius, double? textScale})
      : theme = theme ?? ThemeConfig.values['defaultTheme'] as String,
        overlay = overlay ?? ThemeConfig.number('overlay', 'default'),
        radius = radius ?? ThemeConfig.number('radius', 'default'),
        textScale = textScale ?? ThemeConfig.number('textScale', 'default');
  static Map<String, Color> get themes =>
      (ThemeConfig.values['themes'] as Map<String, dynamic>).map((key, value) =>
        MapEntry(key, Color(int.parse((value as String).replaceFirst('#', 'ff'), radix: 16))));
  bool get dark => theme == ThemeConfig.values['darkTheme'];
  ThemeData get materialTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: themes[theme] ?? themes[ThemeConfig.values['defaultTheme']]!,
      brightness: dark ? Brightness.dark : Brightness.light),
    fontFamily: null,
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius))),
    cardTheme: CardThemeData(shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius))),
  );
  Map<String, dynamic> toJson() => {'theme': theme, 'backgroundPath': backgroundPath,
    'overlay': overlay, 'radius': radius, 'textScale': textScale};
  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
    theme: themes.containsKey(json['theme']) ? json['theme'] as String : ThemeConfig.values['defaultTheme'] as String,
    backgroundPath: json['backgroundPath'] as String?,
    overlay: (json['overlay'] as num? ?? ThemeConfig.number('overlay', 'default')).toDouble().clamp(ThemeConfig.number('overlay', 'min'), ThemeConfig.number('overlay', 'max')),
    radius: (json['radius'] as num? ?? ThemeConfig.number('radius', 'default')).toDouble().clamp(ThemeConfig.number('radius', 'min'), ThemeConfig.number('radius', 'max')),
    textScale: (json['textScale'] as num? ?? ThemeConfig.number('textScale', 'default')).toDouble().clamp(ThemeConfig.number('textScale', 'min'), ThemeConfig.number('textScale', 'max')));
}
