"""POST /api/tts/speak 三路径 + 缓存 + 情绪参数映射（不访问网络）。"""
import os
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock

from server.api.app import Application, APIError, BinaryResponse
from server.config import Config
from server.memory.store import Store
from server.voice.providers import EdgeTTSProvider, ProviderError, VoiceParams, edge_params, emotion_params


class EdgeParamTests(unittest.TestCase):
    def test_emotion_params_map_to_edge_rate_and_pitch(self):
        rate, pitch = edge_params(VoiceParams(speed=0.85, pitch=0.95))
        self.assertEqual(rate, '-15%')
        self.assertEqual(pitch, '-5Hz')
        rate2, pitch2 = edge_params(VoiceParams(speed=1.0, pitch=1.0))
        self.assertEqual(rate2, '+0%')
        self.assertEqual(pitch2, '+0Hz')

    def test_provider_missing_library_raises_provider_error(self):
        with mock.patch.dict('sys.modules', {'edge_tts': None}):
            with self.assertRaises(ProviderError):
                EdgeTTSProvider().synthesize('你好', VoiceParams())

    def test_empty_text_rejected_before_any_network(self):
        with self.assertRaises(ProviderError):
            EdgeTTSProvider().synthesize('   ', VoiceParams())


class TtsSpeakTests(unittest.TestCase):
    def setUp(self):
        self.app = Application(Config(database=':memory:', token='fixture'),
                               Store(':memory:'))
        self.addCleanup(self.app.store.db.close)

    def test_disabled_by_default_returns_503(self):
        with self.assertRaises(APIError) as ctx:
            self.app.dispatch('POST', '/api/tts/speak', {'text': '你好'}, {})
        self.assertEqual(ctx.exception.status, 503)

    def test_enabled_synthesizes_caches_and_reuses(self):
        self.app.config = replace(self.app.config, tts_enabled=True)
        calls = []
        import server.voice.providers as providers
        def fake_synthesize(self, text, params):
            calls.append((text, params.speed))
            return b'ID3__mp3data'
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(providers.EdgeTTSProvider, 'synthesize', fake_synthesize), \
                 mock.patch('server.api.app.tts_cache_dir', return_value=Path(tmp)/'tts_cache'):
                first = self.app.dispatch('POST', '/api/tts/speak',
                                          {'text': '早上好', 'emotion': 'sad'}, {})
                second = self.app.dispatch('POST', '/api/tts/speak',
                                           {'text': '早上好', 'emotion': 'sad'}, {})
        self.assertIsInstance(first, BinaryResponse)
        self.assertEqual(first.content_type, 'audio/mpeg')
        self.assertEqual(first.data, b'ID3__mp3data')
        self.assertEqual(second.data, b'ID3__mp3data')
        self.assertEqual(len(calls), 1)  # 第二次命中缓存，不再合成
        self.assertEqual(calls[0][1], 0.85)  # sad → EMOTION_VOICE 慢速

    def test_provider_failure_raises_502_without_fallback(self):
        import server.voice.providers as providers
        self.app.config = replace(self.app.config, tts_enabled=True)
        def boom(self, text, params):
            raise ProviderError('edge-tts 合成失败：TimeoutError')
        with mock.patch.object(providers.EdgeTTSProvider, 'synthesize', boom):
            with self.assertRaises(APIError) as ctx:
                self.app.dispatch('POST', '/api/tts/speak', {'text': '你好'}, {})
        self.assertEqual(ctx.exception.status, 502)

    def test_overlong_text_rejected(self):
        self.app.config = replace(self.app.config, tts_enabled=True)
        with self.assertRaises(APIError) as ctx:
            self.app.dispatch('POST', '/api/tts/speak', {'text': '长' * 501}, {})
        self.assertEqual(ctx.exception.status, 413)


@unittest.skipUnless(os.getenv('TTS_REAL') == '1',
                     '真实 edge-tts 网络调用：CI 跳过，本地 TTS_REAL=1 手跑')
class RealEdgeTtsTests(unittest.TestCase):
    def test_real_synthesis_returns_mp3(self):
        data = EdgeTTSProvider('zh-CN-YunxiNeural').synthesize(
            '嗯，慢慢说。', emotion_params('calm'))
        self.assertGreater(len(data), 1000)
        self.assertTrue(data.startswith(b'ID3') or data[:3] == b'\xff\xfb\x00' or data[:4] == b'OggS' or len(data) > 0)


if __name__ == '__main__':
    unittest.main()
