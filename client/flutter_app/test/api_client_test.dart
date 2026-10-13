import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/api_client.dart';

void main() {
  test('rejects insecure and credential-bearing cloud endpoint before network', () async {
    for (final address in ['', 'http://localhost:8080', 'https://a:b@example.org', 'https://example.org?token=x']) {
      final api = ApiClient(baseUrl: address);
      await expectLater(api.request('GET','/status'), throwsException);
    }
  });
}
