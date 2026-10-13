import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xinghui_companion/appearance.dart';
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/background_library.dart';
import 'package:xinghui_companion/ambient_background.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(ThemeConfig.load);
 test('ten themes each declare one primary element and settings roundtrip',(){
  expect(Appearance.themes,hasLength(10));
  for(final name in Appearance.themes.keys){
   final a=Appearance(theme:name);expect(['none',...DecorationPlugin.registry.keys],contains(a.background['primary']));
   a.animated=false;a.autoTheme=true;a.plugins['stars']={'count':12,'speed':.4,'opacity':.5};
   final b=Appearance.fromJson(a.toJson());expect(b.animated,isFalse);expect(b.autoTheme,isTrue);expect(b.pluginConfig('stars')['count'],12);
  }
 });
 test('crop resizes to 1920 and creates a 320 thumbnail',(){
  final original=img.Image(width:2400,height:1200);
  final result=compressBackground({'bytes':Uint8List.fromList(img.encodePng(original)),'crop':[0.0,0.0,1.0,1.0],'maxSide':1920,'thumbnailSide':320,'quality':80});
  expect(result['width'],1920);expect(result['height'],960);
  final thumbnail=img.decodeJpg(result['thumbnail'] as Uint8List)!;expect(thumbnail.width,320);expect(thumbnail.height,160);
 });
 testWidgets('hidden window pauses animation', (tester)async{
  await tester.pumpWidget(MaterialApp(home:AmbientBackground(appearance:Appearance())));await tester.pump();
  expect(tester.binding.transientCallbackCount,greaterThan(0));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);await tester.pump();expect(tester.binding.transientCallbackCount,0);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);await tester.pump();expect(tester.binding.transientCallbackCount,greaterThan(0));
  await tester.pumpWidget(const SizedBox.shrink());
 });
}
