import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/version_stamp.dart';
void main(){
 test('version follows base patch and byte-identical rollback, including PowerShell BOM',()async{
  final dir=await Directory.systemTemp.createTemp('version-stamp-');addTearDown(()=>dir.delete(recursive:true));final file=File('${dir.path}/install-state.json');
  final base=jsonEncode({'schema':1,'module':'m145','batch':'base','git_hash':'abcdef0'});
  await file.writeAsString(base);expect(await VersionStamp.read(file),'m145-base · abcdef0');
  await file.writeAsString('\uFEFF${jsonEncode({'schema':1,'module':'m145','batch':'b0','git_hash':'abcdef0'})}');expect(await VersionStamp.read(file),'m145-b0 · abcdef0');
  await file.writeAsString(base);expect(await VersionStamp.read(file),'m145-base · abcdef0');
 });
}
