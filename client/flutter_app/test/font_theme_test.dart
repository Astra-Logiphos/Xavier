import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xinghui_companion/appearance.dart';
import 'package:xinghui_companion/theme_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ThemeConfig.load);
  test('three typography levels and uniform height weight come from assets', () {
    final theme = Appearance().textTheme;
    expect(theme.titleLarge!.fontSize, 20);
    expect(theme.bodyMedium!.fontSize, 15);
    expect(theme.bodySmall!.fontSize, 13);
    for (final style in [theme.titleLarge, theme.bodyMedium, theme.bodySmall]) {
      expect(style!.height, 1.5);
      expect(style.fontWeight, FontWeight.w400);
    }
  });
  test('every bundled font loads without runtime fetching and survives settings', () async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final name in Appearance.fonts) {
      final appearance = Appearance(font: name);
      final theme = appearance.materialTheme;
      await GoogleFonts.pendingFonts();
      expect(Appearance.fromJson(appearance.toJson()).font, name);
      expect(theme.textTheme.titleLarge!.fontSize, 20);
    }
  });
}
