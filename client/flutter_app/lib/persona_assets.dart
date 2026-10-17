import 'dart:convert';
import 'package:flutter/services.dart';

class PersonaAssets {
  static late Map<String, dynamic> data;
  static late Map<String, dynamic> core;
  static Future<void> load() async {
    core = jsonDecode(
            await rootBundle.loadString('assets/persona/persona_v1_4.json'))
        as Map<String, dynamic>;
    data = jsonDecode(
            await rootBundle.loadString('assets/persona/xavier_persona.yaml'))
        as Map<String, dynamic>;
  }

  static String greeting(DateTime when) {
    final slots = core['static']['greetings'] as List;
    return slots.firstWhere(
            (s) => when.hour >= s['start'] && when.hour < s['end'])['line']
        as String;
  }

  static String line(String section, String key, {DateTime? when}) {
    final choices = data['静态台词'][section] as Map<String, dynamic>;
    final lines = ((choices[key] ?? choices['默认']) as List).cast<String>();
    return lines[(when ?? DateTime.now()).day % lines.length];
  }

  static String empty(String key) => data['静态台词']['空状态'][key] as String;
}
