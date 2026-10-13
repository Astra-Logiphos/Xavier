import 'dart:convert';
import 'package:http/http.dart' as http;
import 'offline_demo.dart';

class ApiClient {
  final http.Client transport;
  final OfflineDemo demo = OfflineDemo();
  String baseUrl;
  String token;
  ApiClient({this.baseUrl = '', this.token = '', http.Client? client})
      : transport = client ?? http.Client();

  static bool isLocalEndpoint(Uri uri) =>
      uri.scheme == 'http' && uri.host == '127.0.0.1' &&
      uri.path.isEmpty && uri.port == 8080;

  Future<Map<String, dynamic>> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (baseUrl.isEmpty) return demo.request(method, path, body);
    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.hasAuthority || !isLocalEndpoint(base) ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw Exception('只允许本地后端地址 http://127.0.0.1:8080，不含账号、查询参数或片段。');
    }
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final request = http.Request(method, url);
    request.headers.addAll({'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'});
    request.followRedirects = false;
    if (body != null) request.body = jsonEncode(body);
    final stream = await transport.send(request).timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(stream).timeout(const Duration(seconds: 40));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(decoded['error'] ?? '服务请求失败：${response.statusCode}');
    }
    return decoded;
  }
}
