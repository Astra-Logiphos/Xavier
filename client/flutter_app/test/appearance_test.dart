import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/appearance.dart';

void main() {
  test('theme settings roundtrip and clamp invalid values', () {
    final a = Appearance(theme: '月光', radius: 12, overlay: .7);
    final b = Appearance.fromJson(a.toJson());
    expect(b.theme, '月光'); expect(b.radius, 12); expect(b.dark, false);
    final invalid = Appearance.fromJson({'theme':'unknown','overlay':4,'radius':-1});
    expect(invalid.theme, '星夜'); expect(invalid.overlay, .98); expect(invalid.radius, 0);
  });
}
