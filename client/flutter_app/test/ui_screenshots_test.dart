import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xinghui_companion/appearance.dart';
import 'package:xinghui_companion/main.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/theme_config.dart';
import 'package:xinghui_companion/persona_assets.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();setUpAll(()async{await ThemeConfig.load();await PersonaAssets.load();});
 testWidgets('all pages render without raw summary JSON and export review screenshots',(tester)async{
  tester.view.physicalSize=const Size(1400,1000);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'server_url':'http://127.0.0.1:8080','appearance':jsonEncode({'animated':false,'font':'思源黑体'})});
  const storage=MethodChannel('plugins.it_nomads.com/flutter_secure_storage');tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage,(_)async=>'test-token');
  addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(storage,null));
  final client=MockClient((request)async{
   final result=switch(request.url.path){
    '/status'=>{'persona_version':'fixture','pending_sources':0,'provider':'mock','model_api_enabled':false},
    '/settings'=>{'save_conversations':true,'language':'zh-CN'},
    '/daily'=>{'summary':{'learned':['读了一页书'],'events':[{'text':'给小鸟留了食物'}]},'turns':[]},
    '/conversations'=>{'items':[{'user_text':'今天读了一页书','assistant_text':'嗯，我陪你。','id':'turn','emotion':{}}]},
    '/food-logs'=>{'items':[],'calories':0},
    '/foods'=>{'items':[]},
    _=>{'items':[]},
   };
   return http.Response(jsonEncode(result),200,headers:{'content-type':'application/json; charset=utf-8'});
  });
  await tester.runAsync(()=>rootBundle.loadString('assets/data/foods.json'));
  await tester.runAsync(() async {
    Appearance(font:'思源黑体').materialTheme; await GoogleFonts.pendingFonts();
    final loader=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));await loader.load();
  });
  final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:XinghuiApp(client:ApiClient(client:client))));await tester.pumpAndSettle();
  final directory=Directory('../../runtime/ui-checks');directory.createSync(recursive:true);
  final images=<ui.Image>[];
  final pages=['今日','聊天','学习','审核与人设','来源','记忆','外观','设置','学习规则','关于星回','热量追踪'];
  for(var index=0;index<pages.length;index++){
   await tester.tap(find.text(pages[index]).first);await tester.pump();await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:200)));await tester.pumpAndSettle();expect(tester.takeException(),isNull,reason:pages[index]);
   if(index==0){expect(find.textContaining('chat_topics'),findsNothing);expect(find.textContaining('offline-preview'),findsNothing);expect(find.textContaining('读了一页书'),findsWidgets);}
   final boundary=key.currentContext!.findRenderObject() as RenderRepaintBoundary;
   final image=await tester.runAsync(()=>boundary.toImage(pixelRatio:1));
   final bytes=await tester.runAsync(()=>image!.toByteData(format:ui.ImageByteFormat.png));
   File('${directory.path}/page-$index.png').writeAsBytesSync(bytes!.buffer.asUint8List());images.add(image!);
  }
  await tester.tap(find.text('外观').first);await tester.pumpAndSettle();
  for(var index=0;index<Appearance.themes.length;index++){
    final name=Appearance.themes.keys.elementAt(index);
    await tester.tap(find.textContaining(name).first);await tester.pumpAndSettle();expect(tester.takeException(),isNull,reason:name);
    final boundary=key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image=await tester.runAsync(()=>boundary.toImage(pixelRatio:1));final bytes=await tester.runAsync(()=>image!.toByteData(format:ui.ImageByteFormat.png));
    File('${directory.path}/theme-$index.png').writeAsBytesSync(bytes!.buffer.asUint8List());image!.dispose();
  }
  final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);const tile=Size(420,300);
  for(var i=0;i<images.length;i++){final target=Rect.fromLTWH((i%3)*tile.width,(i~/3)*tile.height,tile.width,tile.height);canvas.drawImageRect(images[i],Rect.fromLTWH(0,0,images[i].width.toDouble(),images[i].height.toDouble()),target,Paint());}
  final picture=recorder.endRecording();final contact=await tester.runAsync(()=>picture.toImage(1260,1200));final bytes=await tester.runAsync(()=>contact!.toByteData(format:ui.ImageByteFormat.png));
  File('${directory.path}/contact.png').writeAsBytesSync(bytes!.buffer.asUint8List());for(final image in images){image.dispose();}contact!.dispose();picture.dispose();
  await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
 });
}
