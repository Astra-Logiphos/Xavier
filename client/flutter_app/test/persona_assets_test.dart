import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/persona_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PersonaAssets.load);
  test('all requested sections and nine report scenes are preserved', () {
    for (final key in ['基础档案', '外貌', '表层性格', '私下性格', '情绪场景表', '喜好与生活习惯', '怪癖', '代表台词', '禁忌']) {
      expect(PersonaAssets.data[key], isNotEmpty);
    }
    expect(PersonaAssets.data['情绪场景表'], hasLength(9));
    expect(PersonaAssets.data['基础档案']['中文名'], contains('沈星回'));
  });
  test('morning noon evening greetings differ with persona speech', () {
    final lines = [8, 12, 20].map((hour) => PersonaAssets.greeting(DateTime(2026, 10, 13, hour))).toSet();
    expect(lines, hasLength(3));
    expect(lines.any((line) => line.contains('鸟') || line.contains('肉') || line.contains('杨桃')), isTrue);
  });
  test('all checkins have authored encouragement and reminder lines', () {
    for (final category in ['学习', '情绪', '陪伴', '饮食', '运动']) {
      expect(PersonaAssets.line('鼓励', category), isNotEmpty);
      expect(PersonaAssets.line('提醒', category), isNotEmpty);
    }
    expect(PersonaAssets.empty('记忆'), contains('记住'));
    expect(PersonaAssets.line('鼓励', '自定义'), isNotEmpty);
  });
}
