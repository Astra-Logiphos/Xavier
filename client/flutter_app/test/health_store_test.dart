import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/health_store.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('food grams, MET hours, daily snapshots and durable local storage',()async{
  final directory=await Directory.systemTemp.createTemp('health-test-');
  const channel=MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_)async=>directory.path);
  addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  final store=HealthStore();await store.open(directory:directory.path);
  await store.profile(70,1500,1.2);
  expect(store.target,1800);
  expect(HealthStore.intake(200,50),100);
  expect(HealthStore.expenditure(7.5,70,30),262.5);
  final date=HealthStore.date(DateTime.now());
  await store.add(date,'foods',{'name':'测试食物','calories':100.0});
  await store.add(date,'exercises',{'name':'慢跑','calories':262.5});
  expect(store.net(date),-162.5);
  await store.custom('自定义',200);
  expect((jsonDecode(File('${directory.path}/xinghui-health.gs').readAsStringSync())['data']['days'] as Map).length,1);
  final restored=HealthStore();await restored.open(directory:directory.path);
  expect(restored.net(date),-162.5);expect(restored.customFoods.single['energyKCal'],200);
  await restored.profile(80,1600,1.3);expect(restored.total(date,'exercises'),262.5);
  final export=restored.export();await restored.remove(date,'foods',restored.rows(date,'foods').single['id']);expect(restored.total(date,'foods'),0);
  await restored.restore(export);expect(restored.total(date,'foods'),100);
  await expectLater(restored.profile(double.nan,1500,1.2),throwsFormatException);
  await expectLater(restored.add('bad','foods',{'calories':0}),throwsFormatException);
 });
}
