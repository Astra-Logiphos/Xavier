import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/record_editor.dart';
void main() {
  testWidgets('memory form offers fields and explicit consent without JSON', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:RecordEditor(
      title:'添加记忆',initial:{'content':'喜欢星空','consent':true,'confidence':1.0}))));
    expect(find.text('添加记忆'),findsOneWidget);
    expect(find.byType(TextFormField),findsNWidgets(2));
    expect(find.byType(SwitchListTile),findsOneWidget);
    expect(find.text('保存'),findsOneWidget);
  });
}
