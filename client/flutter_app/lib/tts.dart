import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 情绪 → 朗读参数（温柔沉稳基调：语速 0.90–1.05，音调始终略低于默认）。
class EmotionVoice {
  final double rate, pitch;
  const EmotionVoice(this.rate, this.pitch);
  static const neutral = EmotionVoice(0.95, 0.92);
  static const table = <String, EmotionVoice>{
    'neutral': EmotionVoice(0.95, 0.92),
    'calm': EmotionVoice(0.92, 0.90),
    'sad': EmotionVoice(0.90, 0.88),
    'anxious': EmotionVoice(0.98, 0.92),
    'tired': EmotionVoice(0.90, 0.88),
    'happy': EmotionVoice(1.02, 0.95),
    'excited': EmotionVoice(1.05, 0.98),
  };
  static EmotionVoice of(String? emotion) =>
      (emotion == null ? null : table[emotion]) ?? neutral;
}

/// 系统朗读后端抽象；测试注入假实现，不触碰插件通道。
abstract class SystemTtsBackend {
  Future<void> configure(String language, double rate, double pitch);
  Future<Object?> speak(String text);
  Future<void> stop();
}

class FlutterTtsBackend implements SystemTtsBackend {
  final FlutterTts _tts = FlutterTts();
  @override
  Future<void> configure(String language, double rate, double pitch) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
  }

  @override
  Future<Object?> speak(String text) => _tts.speak(text);
  @override
  Future<void> stop() => _tts.stop();
}

/// 云端优先朗读钩子：返回 true 表示已由云端音频接管本轮播放。
typedef CloudSpeak = Future<bool> Function(String text, String? emotion);

class TtsService {
  TtsService();
  static final TtsService instance = TtsService();
  final speaking = ValueNotifier<String?>(null);
  SystemTtsBackend? backend;
  CloudSpeak? cloudFirst;
  String language = 'zh-CN';

  Future<void> stop() async {
    speaking.value = null;
    await backend?.stop();
    await onCloudStop?.call();
  }

  Future<void> Function()? onCloudStop;

  Future<void> speak(String id, String text, String? emotion) async {
    if (text.isEmpty) return;
    await stop();
    if (cloudFirst != null && await cloudFirst!(text, emotion)) {
      speaking.value = id;
      return;
    }
    final engine = backend ??= FlutterTtsBackend();
    final voice = EmotionVoice.of(emotion);
    await engine.configure(language, voice.rate, voice.pitch);
    speaking.value = id;
    await engine.speak(text);
    if (speaking.value == id) speaking.value = null;
  }
}
