import 'package:flutter/material.dart';

class Appearance {
  String theme;
  String? backgroundPath;
  double overlay;
  double radius;
  double textScale;
  Appearance({this.theme = '星夜', this.backgroundPath, this.overlay = .85,
    this.radius = 20, this.textScale = 1.0});
  static const themes = {'星夜': Color(0xff9fa8ff), '月光': Color(0xff6baec2),
    '暖春': Color(0xffcc8ba1)};
  bool get dark => theme == '星夜';
  ThemeData get materialTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: themes[theme] ?? themes['星夜']!,
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
    theme: themes.containsKey(json['theme']) ? json['theme'] as String : '星夜',
    backgroundPath: json['backgroundPath'] as String?,
    overlay: (json['overlay'] as num? ?? .85).toDouble().clamp(.4, .98),
    radius: (json['radius'] as num? ?? 20).toDouble().clamp(0, 32),
    textScale: (json['textScale'] as num? ?? 1).toDouble().clamp(.85, 1.4));
}
