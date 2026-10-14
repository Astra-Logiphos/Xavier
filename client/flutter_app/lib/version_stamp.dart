import 'dart:convert';
import 'dart:io';

class VersionStamp {
  static String current='版本尚未配置';
  static Future<String> read(File file) async {
    final state=jsonDecode((await file.readAsString()).replaceFirst('\uFEFF',''));
    if(state['schema']!=1||!RegExp(r'^m[0-9]+$').hasMatch(state['module'] as String)||!RegExp(r'^(base|b[0-9]+)$').hasMatch(state['batch'] as String)||!RegExp(r'^[0-9a-f]{7,40}$').hasMatch(state['git_hash'] as String))throw const FormatException('版本信息无效');
    return '${state['module']}-${state['batch']} · ${state['git_hash']}';
  }
  static Future<void> load() async {
    final file=File('${File(Platform.resolvedExecutable).parent.path}/install-state.json');
    if(await file.exists()){current=await read(file);}
  }
}
