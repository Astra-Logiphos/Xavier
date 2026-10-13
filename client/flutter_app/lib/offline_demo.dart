/// Standalone free preview. Session-only rules; never calls a model or saves chats.
class OfflineDemo {
  final Map<String, dynamic> settings = {
    'save_conversations': false, 'emotion_enabled': false, 'voice_enabled': false,
    'language': 'zh-CN', 'reminders_enabled': false, 'reminders_paused': false,
  };
  String get today => DateTime.now().toIso8601String().substring(0, 10);
  final List<Map<String, dynamic>> checkins = [];

  Future<Map<String, dynamic>> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final b = body ?? {};
    final endpoint = path.split('?').first;
    if (method == 'GET' && endpoint == '/status') {
      return {'persona_version': 'offline-preview-1', 'pending_sources': 0,
        'provider': 'free_rules_offline', 'model_api_enabled': false,
        'allow_paid_api': false, 'voice': 'mock_only',
        'notice': '无需配置即可体验。会话与打卡仅本次打开有效；本地长期记忆需连接后端。'};
    }
    if (endpoint == '/settings') {
      if (method == 'PATCH') {
        if (b['save_conversations'] == true) {
          throw Exception('离线预览不保存聊天。请连接本地后端再开启长期记录。');
        }
        settings.addAll(b);
      }
      return Map<String, dynamic>.from(settings);
    }
    if (method == 'POST' && endpoint == '/chat') {
      final text = '${b['text'] ?? ''}';
      String reply;
      if (text.contains('不要记住') || text.contains('不要记录')) {
        reply = '好，这一轮不会保存。离线预览本来也不会记录聊天。';
      } else if (text.startsWith('记住这件事') || text.startsWith('今天学了') ||
          text.contains('上次') || text.contains('我希望你')) {
        reply = '我听见了。这个预览还没有连接本地长期记忆，不能说已经记住。你可以先体验界面；连接后端后再记录和审核。';
      } else if (b['mode'] != 'chat') {
        reply = '我们慢慢看。现在是免费规则预览，没有专业模型或资料检索；我无法核实技术结论。';
      } else if (text.contains('累') || text.contains('难过') || text.contains('焦虑') || text.contains('生气')) {
        reply = '先缓一缓。我在这里。愿意的话，可以慢慢说说今天发生了什么。';
      } else if (text.trim() == '…' || text.trim().isEmpty) {
        reply = '不想说话也没关系，我们可以先安静一会儿。';
      } else {
        reply = '我在，慢慢说。现在是免费规则体验，尚未连接大模型；可以先聊聊今天，也可以换一个喜欢的背景。';
      }
      return {'reply': reply, 'saved': false, 'turn_id': null, 'local_date': today,
        'emotion': {'label': 'neutral', 'confidence': 0, 'method': 'disabled'}};
    }
    if (endpoint == '/daily') {
      return {'summary': {'notice': '离线规则预览，没有保存或本地日总结。',
        'local_date': today, 'learned': []}, 'turns': []};
    }
    if (endpoint == '/checkins') {
      if (method == 'POST') {
        final category = '${b['category'] ?? '陪伴'}';
        final day = '${b['local_date'] ?? today}';
        if (!checkins.any((r) => r['category'] == category && r['local_date'] == day)) {
          checkins.add({'category': category, 'local_date': day});
        }
        return {'notice': '本次体验已打卡；预览不保存长期打卡数据。'};
      }
      return {'items': checkins, 'notice': '仅本次打开的临时打卡'};
    }
    if (endpoint == '/voice/stt' || endpoint == '/voice/tts') {
      return {'mock': true, 'audio_url': null, 'notice': '语音尚为模拟，没有录音或生成音频。'};
    }
    if (endpoint == '/data' && method == 'DELETE') {
      checkins.clear();
      return {'deleted': true, 'notice': '已清空本次体验的临时数据。'};
    }
    if (endpoint == '/data/export' || endpoint == '/persona/export') {
      throw Exception('离线预览没有本地个人数据或正式人设可导出。');
    }
    if (method == 'GET' && ['/learning', '/memories', '/review', '/sources',
      '/traits', '/persona/versions', '/rules', '/memory-candidates'].contains(endpoint)) {
      return {'items': [], 'notice': '该功能需在设置中连接本地后端。'};
    }
    throw Exception('此功能需要本地后端。先体验聊天和外观，或在设置中填写 本地地址 http://127.0.0.1:8080与访问令牌。');
  }
}
