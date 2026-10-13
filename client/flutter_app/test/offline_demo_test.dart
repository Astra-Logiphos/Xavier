import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/api_client.dart';
void main() {
  test('empty endpoint provides honest standalone rule preview', () async {
    final api = ApiClient();
    final status = await api.request('GET', '/status');
    expect(status['provider'], 'free_rules_offline');
    final chat = await api.request('POST', '/chat', {'text':'今天很累','mode':'chat'});
    expect(chat['reply'], contains('先缓一缓'));
    expect(chat['saved'], false);
    final memories = await api.request('GET', '/memories');
    expect(memories['items'], isEmpty);
    await expectLater(api.request('POST','/memories',{'content':'fixture'}),throwsException);
  });
}
