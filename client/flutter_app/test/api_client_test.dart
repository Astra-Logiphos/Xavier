import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/api_client.dart';

void main() {
  test('only fixed local loopback endpoint is accepted', () {
    expect(ApiClient.isLocalEndpoint(Uri.parse('http://127.0.0.1:8080')), isTrue);
    expect(ApiClient.isLocalEndpoint(Uri.parse('http://127.0.0.1:8081')), isFalse);
    expect(ApiClient.isLocalEndpoint(Uri.parse('https://example.org')), isFalse);
  });
  test('rejects remote and credential-bearing endpoint before network', () async {
    for (final address in ['http://192.168.1.1:8080', 'https://a:b@example.org', 'https://example.org?token=x']) {
      final api = ApiClient(baseUrl: address);
      await expectLater(api.request('GET','/status'), throwsException);
    }
  });
}
