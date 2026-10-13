import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  String baseUrl;
  String token;
  ApiClient({this.baseUrl = '', this.token = ''});

  Future<Map<String, dynamic>> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.hasAuthority || base.scheme != 'https' ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw Exception('请在设置中填写 HTTPS 云端服务地址，不含账号、查询参数或片段。');
    }
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final request = http.Request(method, url);
    request.headers.addAll({'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'});
    request.followRedirects = false;
    if (body != null) request.body = jsonEncode(body);
    final stream = await request.send().timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(stream);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(decoded['error'] ?? '服务请求失败：${response.statusCode}');
    }
    return decoded;
  }
}
