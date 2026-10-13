import 'dart:convert';
import 'package:flutter/services.dart';

class PersonaAssets {
  static late Map<String, dynamic> data;
  static Future<void> load() async {
    data = jsonDecode(await rootBundle.loadString('assets/persona/xavier_persona.yaml')) as Map<String, dynamic>;
  }
  static String greeting(DateTime when) {
    final slots = data['静态台词']['问候'] as List;
    final slot = slots.firstWhere((s) => when.hour >= s['start'] && when.hour < s['end']);
    final lines = (slot['lines'] as List).cast<String>();
    return lines[when.day % lines.length];
  }
  static String line(String section, String key, {DateTime? when}) {
    final choices = data['静态台词'][section] as Map<String, dynamic>;
    final lines = ((choices[key] ?? choices['默认']) as List).cast<String>();
    return lines[(when ?? DateTime.now()).day % lines.length];
  }
  static String empty(String key) => data['静态台词']['空状态'][key] as String;
}
