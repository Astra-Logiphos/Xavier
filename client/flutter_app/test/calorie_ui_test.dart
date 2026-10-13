import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/api_client.dart';
import 'package:xinghui_companion/nutrition_page.dart';
import 'package:xinghui_companion/health_store.dart';
import 'package:xinghui_companion/persona_assets.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late List sources;
 setUpAll(()async{await PersonaAssets.load();sources=(jsonDecode(await rootBundle.loadString('assets/data/foods.json')) as List).where((f)=>(f['foodName'] as String).contains('米饭')).toList();await rootBundle.loadString('assets/data/exercises.json');});
 testWidgets('offline diet and exercise controls save real daily calorie totals',(tester)async{
  tester.view.physicalSize=const Size(1400,1000);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);

  final store=HealthStore.instance;await store.profile(70,1500,1.2);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:NutritionPage(api:ApiClient(),connected:false))));await tester.pump();await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:200)));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'搜索食物，例如米饭'),'米饭');await tester.pumpAndSettle();
  final rows=find.byType(RadioListTile<int>);expect(rows,findsWidgets);

  final index=sources.indexWhere((f)=>f['energyKCal'] is num);expect(index,greaterThanOrEqualTo(0));
  await tester.ensureVisible(rows.at(index));await tester.tap(rows.at(index));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'实际摄入份量'),'150');
  await tester.ensureVisible(find.text('记录饮食'));await tester.tap(find.text('记录饮食'));await tester.pumpAndSettle();
  final day=HealthStore.date(DateTime.now());expect(store.total(day,'foods'),closeTo((sources[index]['energyKCal'] as num)*1.5,0.001));
  await tester.tap(find.text('运动'));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'搜索运动（支持慢跑或英文原名）'),'慢跑');await tester.pumpAndSettle();
  final jogging=find.byType(RadioListTile<String>);expect(jogging,findsOneWidget);await tester.tap(jogging);await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'运动分钟数'),'30');await tester.ensureVisible(find.text('记录运动'));await tester.tap(find.text('记录运动'));await tester.pumpAndSettle();
  expect(store.total(day,'exercises'),262.5);expect(store.net(day),closeTo(store.total(day,'foods')-262.5,0.001));expect(tester.takeException(),isNull);
 });
}
