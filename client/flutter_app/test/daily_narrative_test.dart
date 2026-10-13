import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/companion_ui.dart';
import 'package:xinghui_companion/persona_assets.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();setUpAll(PersonaAssets.load);
 test('daily summary renders actual records as prose without JSON metadata',(){
  final result=dailyNarrative({'learned':['阅读'],'events':[{'text':'完成了一页笔记','source_turn_id':'hidden'}]});
  expect(result,contains('阅读'));expect(result,contains('完成了一页笔记'));expect(result, isNot(contains('source_turn_id')));expect(result,isNot(contains('{')));
 });
 test('empty summary has persona invitation',(){expect(dailyNarrative({}),isNotEmpty);});
}
