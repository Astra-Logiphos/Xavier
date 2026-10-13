import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/reminder_service.dart';
import 'package:xinghui_companion/persona_assets.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('five persona reminders and daily date rollover',()async{
  await PersonaAssets.load();
  for(final c in ReminderService.categories){expect(PersonaAssets.line('提醒',c),isNotEmpty);}
  final dates=ReminderService.nextDates(DateTime(2026,12,31,23,59),0,5,8);
  expect(dates.length,7);expect(dates.first,DateTime(2027,1,1,0,5));expect(dates.last,DateTime(2027,1,7,0,5));
  expect(()=>ReminderService.nextDates(DateTime.now(),24,0,2),throwsFormatException);
 });
}
