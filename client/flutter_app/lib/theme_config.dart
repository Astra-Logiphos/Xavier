import 'dart:convert';
import 'package:flutter/services.dart';

/// theme.yaml uses YAML 1.2's JSON-compatible notation to avoid parser ambiguity.
class ThemeConfig {
  static late Map<String, dynamic> values;
  static Future<void> load() async {
    values = jsonDecode(await rootBundle.loadString('assets/theme.yaml'))
        as Map<String, dynamic>;
  }
  static double number(String section, String key) =>
      (values[section][key] as num).toDouble();
}
