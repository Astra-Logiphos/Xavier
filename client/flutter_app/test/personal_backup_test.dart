import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/health_store.dart';
import 'package:xinghui_companion/personal_backup.dart';
import 'package:xinghui_companion/theme_config.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('full JSON backup restores local profile, daily health, settings and photo bytes',()async{
  await ThemeConfig.load();final dir=await Directory.systemTemp.createTemp('xinghui-backup-');
  const channel=MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_)async=>dir.path);
  addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  final photo=File('${dir.path}/photo-123.jpg'),thumb=File('${dir.path}/thumb-123.jpg');
  final jpeg=img.encodeJpg(img.Image(width:8,height:8));await photo.writeAsBytes(jpeg);await thumb.writeAsBytes(jpeg);
  SharedPreferences.setMockInitialValues({'appearance':jsonEncode({'backgroundPath':photo.path,'font':'思源宋体'}),'background_gallery':jsonEncode([{'path':photo.path,'thumbnail':thumb.path}]),'local_reminders':jsonEncode({for(final c in ['学习','情绪','陪伴','饮食','运动'])c:{'enabled':c=='学习','hour':20,'minute':30}}),'server_url':'http://127.0.0.1:8080','access_token':'NEVER_EXPORT'});
  final health=HealthStore.instance;await health.open(directory:dir.path);await health.profile(70,1500,1.2);final day=HealthStore.date(DateTime.now());await health.add(day,'foods',{'name':'测试','calories':100.0});
  Map<String,dynamic> backend={'format':'xinghui-backend-1','records':[{'id':'chat','kind':'conversation','user_text':'看小鸟'}],'settings':{'save_conversations':true}};
  final original=jsonDecode(jsonEncode(backend));
  final api=ApiClient(baseUrl:'http://127.0.0.1:8080',client:MockClient((request)async{if(request.method=='POST'){backend=jsonDecode(request.body);return http.Response('{}',200);}return http.Response(jsonEncode(backend),200,headers:{'content-type':'application/json; charset=utf-8'});}));
  final backup=await PersonalBackup.export(api);expect(jsonEncode(backup),isNot(contains('NEVER_EXPORT')));expect(backup['preferences'],isNot(contains('server_url')));
  backend={'records':[]};await health.restore({'days':{},'customFoods':[],'weight':0.0,'bmr':0.0,'activityFactor':1.2});final prefs=await SharedPreferences.getInstance();await prefs.remove('appearance');await prefs.remove('local_reminders');
  await PersonalBackup.restore(api,backup,directory:dir.path);
  expect(backend,original);expect(health.total(day,'foods'),100);expect(health.weight,70);
  final appearance=jsonDecode(prefs.getString('appearance')!);expect(appearance['font'],'思源宋体');expect(File(appearance['backgroundPath']).readAsBytesSync(),photo.readAsBytesSync());
  expect(jsonDecode(prefs.getString('local_reminders')!)['学习']['enabled'],true);
  final invalid=jsonDecode(jsonEncode(backup)) as Map<String,dynamic>;invalid['photos'][0]['id']='../outside';
  await expectLater(PersonalBackup.restore(api,invalid,directory:dir.path),throwsFormatException);expect(backend,original);
 });
}
