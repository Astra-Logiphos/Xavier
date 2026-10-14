import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'theme_config.dart';
import 'package:google_fonts/google_fonts.dart';

class Appearance {
  String quality;
  String theme;
  String font;
  String skin;
  bool autoTheme;
  bool animated;
  Map<String, dynamic> plugins;
  String? backgroundPath;
  double overlay;
  double radius;
  double textScale;
  Appearance(
      {String? quality,
      String? theme,
      String? font,
      String? skin,
      this.backgroundPath,
      this.autoTheme = false,
      this.animated = true,
      Map<String, dynamic>? plugins,
      double? overlay,
      double? radius,
      double? textScale})
      : quality = qualities.contains(quality)
            ? quality!
            : ThemeConfig.values['performance']['defaultQuality'] as String,
        plugins = plugins ?? {},
        skin = skin ?? ThemeConfig.values['defaultSkin'] as String,
        font = font ?? ThemeConfig.values['defaultFont'] as String,
        theme = normalizeTheme(
            theme ?? ThemeConfig.values['defaultTheme'] as String),
        overlay = overlay ?? ThemeConfig.number('overlay', 'default'),
        radius = radius ?? ThemeConfig.number('radius', 'default'),
        textScale = textScale ?? ThemeConfig.number('textScale', 'default');
  static List<String> get qualities =>
      (ThemeConfig.values['performance']['qualities'] as Map<String, dynamic>)
          .keys
          .toList();
  Map<String, dynamic> get qualityConfig => ThemeConfig.values['performance']
      ['qualities'][quality] as Map<String, dynamic>;
  bool get blurEnabled => qualityConfig['blur'] == true;
  bool get motionEnabled =>
      animated && (qualityConfig['particleScale'] as num) > 0;
  static Map<String, Color> get themes =>
      (ThemeConfig.values['themes'] as Map<String, dynamic>).map((key, value) =>
          MapEntry(
              key,
              Color(int.parse((value as String).replaceFirst('#', 'ff'),
                  radix: 16))));
  static String normalizeTheme(dynamic value) {
    if (themes.containsKey(value)) return value as String;
    return ThemeConfig.values['themeAliases'][value] as String? ??
        ThemeConfig.values['defaultTheme'] as String;
  }

  String get effectiveTheme {
    if (!autoTheme) return theme;
    final hour = DateTime.now().hour;
    return (ThemeConfig.values['autoThemes'] as List).firstWhere(
            (slot) => hour >= slot['start'] && hour < slot['end'])['theme']
        as String;
  }

  Map<String, dynamic> get background =>
      ThemeConfig.values['backgrounds'][effectiveTheme] as Map<String, dynamic>;
  bool get dark => background['dark'] == true;
  Map<String, dynamic> pluginConfig(String type) {
    final base =
        Map<String, dynamic>.from(ThemeConfig.values['plugins'][type] as Map);
    if (background['primary'] == type) {
      for (final key in ['count', 'speed', 'opacity', 'size']) {
        base[key] = background[key];
      }
    }
    if (background['secondary'] == type) {
      base['count'] = background['secondaryCount'];
      base['opacity'] = background['secondaryOpacity'];
    }
    base.addAll((plugins[type] as Map?)?.cast<String, dynamic>() ?? {});
    base['count'] = ((base['count'] as num).clamp(0, base['countMax'] as num) *
            (ThemeConfig.values['performance']['particleScale'] as num) *
            (qualityConfig['particleScale'] as num))
        .round();
    if (!blurEnabled) base['glowBlur'] = 0;
    base['size'] = (base['size'] as num)
        .clamp(base['sizeMin'] as num, base['sizeMax'] as num);
    base['speed'] = (base['speed'] as num)
        .clamp(base['speedMin'] as num, base['speedMax'] as num);
    base['opacity'] = (base['opacity'] as num).clamp(0, 1);
    return base;
  }

  static List<String> get fonts =>
      (ThemeConfig.values['fonts'] as Map<String, dynamic>).keys.toList();
  static List<String> get skins =>
      (ThemeConfig.values['skins'] as Map<String, dynamic>).keys.toList();
  Color skinColor(String key) => Color(int.parse(
      (ThemeConfig.values['skins'][autoTheme ? background['skin'] : skin][key]
              as String)
          .replaceFirst('#', 'ff'),
      radix: 16));
  TextTheme get textTheme {
    final common = TextStyle(
        fontVariations: [
          ui.FontVariation('wght', ThemeConfig.number('text', 'weight'))
        ],
        height: ThemeConfig.number('text', 'height'),
        fontWeight: FontWeight
            .values[(ThemeConfig.number('text', 'weight') / 100).round() - 1]);
    final title =
        common.copyWith(fontSize: ThemeConfig.number('text', 'headingSize'));
    final body =
        common.copyWith(fontSize: ThemeConfig.number('text', 'bodySize'));
    final auxiliary =
        common.copyWith(fontSize: ThemeConfig.number('text', 'auxiliarySize'));
    final basic = TextTheme(
        displayLarge: title,
        displayMedium: title,
        displaySmall: title,
        headlineLarge: title,
        headlineMedium: title,
        headlineSmall: title,
        titleLarge: title,
        titleMedium: title,
        titleSmall: title,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: auxiliary,
        labelLarge: body,
        labelMedium: auxiliary,
        labelSmall: auxiliary);
    final family = ThemeConfig.values['fonts'][font] as String?;
    if (family == null) {
      return basic.apply(
          bodyColor: skinColor('text'), displayColor: skinColor('text'));
    }
    GoogleFonts.config.allowRuntimeFetching = false;
    return GoogleFonts.getTextTheme(family, basic)
        .apply(bodyColor: skinColor('text'), displayColor: skinColor('text'));
  }

  ThemeData get materialTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: skinColor('primary'),
            brightness: Brightness.light,
            surface: skinColor('background'),
            onSurface: skinColor('text'),
            tertiary: skinColor('accent')),
        textTheme: textTheme,
        inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius))),
        cardTheme: CardThemeData(
            elevation: (ThemeConfig.values['cardElevation'] as num).toDouble(),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius))),
      );
  Map<String, dynamic> toJson() => {
        'quality': quality,
        'theme': theme,
        'font': font,
        'skin': skin,
        'autoTheme': autoTheme,
        'animated': animated,
        'plugins': plugins,
        'backgroundPath': backgroundPath,
        'overlay': overlay,
        'radius': radius,
        'textScale': textScale
      };
  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
      quality: json['quality'] as String?,
      theme: normalizeTheme(json['theme']),
      autoTheme: json['autoTheme'] == true,
      animated: json['animated'] != false,
      plugins: (json['plugins'] as Map?)?.cast<String, dynamic>(),
      skin: skins.contains(json['skin'])
          ? json['skin'] as String
          : ThemeConfig.values['defaultSkin'] as String,
      font: fonts.contains(json['font'])
          ? json['font'] as String
          : ThemeConfig.values['defaultFont'] as String,
      backgroundPath: json['backgroundPath'] as String?,
      overlay:
          (json['overlay'] as num? ?? ThemeConfig.number('overlay', 'default'))
              .toDouble()
              .clamp(ThemeConfig.number('overlay', 'min'),
                  ThemeConfig.number('overlay', 'max')),
      radius:
          (json['radius'] as num? ?? ThemeConfig.number('radius', 'default'))
              .toDouble()
              .clamp(ThemeConfig.number('radius', 'min'),
                  ThemeConfig.number('radius', 'max')),
      textScale: (json['textScale'] as num? ??
              ThemeConfig.number('textScale', 'default'))
          .toDouble()
          .clamp(ThemeConfig.number('textScale', 'min'),
              ThemeConfig.number('textScale', 'max')));
}
