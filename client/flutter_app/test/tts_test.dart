import 'package:flutter_test/flutter_test.dart';
import 'package:xinghui_companion/tts.dart';

class FakeBackend implements SystemTtsBackend {
  double? rate, pitch;
  String language = '', spoken = '';
  int stops = 0;
  @override
  Future<void> configure(String language, double rate, double pitch) async {
    this.language = language;
    this.rate = rate;
    this.pitch = pitch;
  }

  @override
  Future<Object?> speak(String text) async {
    spoken = text;
    return 1;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

TtsService freshService(FakeBackend backend) {
  final service = TtsService();
  // 单例仅供 UI 使用；测试直接构造新实例并通过 backend 字段注入假后端。
  service.backend = backend;
  return service;
}

void main() {
  test('emotion mapping stays gentle: rate 0.90-1.05, pitch below default',
      () {
    for (final entry in EmotionVoice.table.entries) {
      final voice = entry.value;
      expect(voice.rate, inInclusiveRange(0.90, 1.05), reason: entry.key);
      expect(voice.pitch, lessThan(1.0), reason: entry.key);
      expect(voice.pitch, greaterThanOrEqualTo(0.85), reason: entry.key);
    }
  });
  test('unknown or missing emotion falls back to neutral', () {
    expect(EmotionVoice.of(null).rate, EmotionVoice.neutral.rate);
    expect(EmotionVoice.of('whatever').rate, EmotionVoice.neutral.rate);
    expect(EmotionVoice.of('sad').rate, 0.90);
    expect(EmotionVoice.of('excited').rate, 1.05);
  });
  test('system speak configures voice params and clears speaking state',
      () async {
    final backend = FakeBackend();
    final service = freshService(backend);
    await service.speak('a1', '慢慢说。', 'sad');
    expect(backend.spoken, '慢慢说。');
    expect(backend.language, 'zh-CN');
    expect(backend.rate, 0.90);
    expect(backend.pitch, 0.88);
    expect(service.speaking.value, isNull);
  });
  test('empty text never reaches the engine', () async {
    final backend = FakeBackend();
    final service = freshService(backend);
    await service.speak('a2', '', null);
    expect(backend.spoken, '');
    expect(service.speaking.value, isNull);
  });
  test('cloud failure falls back to system tts', () async {
    final backend = FakeBackend();
    final service = freshService(backend);
    service.cloudFirst = (text, emotion) async => false;
    await service.speak('a3', '回退到系统。', 'calm');
    expect(backend.spoken, '回退到系统。');
    expect(backend.rate, 0.92);
  });
  test('cloud success takes over and system engine stays silent', () async {
    final backend = FakeBackend();
    final service = freshService(backend);
    service.cloudFirst = (text, emotion) async => true;
    await service.speak('a4', '云端播放。', null);
    expect(backend.spoken, '');
    expect(service.speaking.value, 'a4');
  });
  test('stop clears speaking and notifies both engines', () async {
    final backend = FakeBackend();
    final service = freshService(backend);
    var cloudStopped = 0;
    service.onCloudStop = () async => cloudStopped++;
    service.cloudFirst = (text, emotion) async => true;
    await service.speak('a5', '正在播放', null);
    await service.stop();
    expect(service.speaking.value, isNull);
    expect(cloudStopped, 1);
    expect(backend.stops, 1);
  });
}
