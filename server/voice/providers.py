"""UNVERIFIED PLACEHOLDER（语音连接器）：仅 Mock STT/TTS。

真实语音识别与合成未接入；Mock 实现不录音、不合成音频，响应里
以 notice 字段明确标注“模拟”。接入真实引擎前不得移除该声明。
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, asdict

@dataclass
class VoiceParams:
    language: str = 'zh-CN'
    emotion: str = 'neutral'
    speed: float = 1.0
    pitch: float = 1.0
    volume: float = .8
    pause: float = .3

class STTProvider(ABC):
    @abstractmethod
    def transcribe(self, text_fixture, params): ...
class TTSProvider(ABC):
    @abstractmethod
    def synthesize(self, text, params): ...
class MockSTTProvider(STTProvider):
    def transcribe(self, text_fixture, params):
        return {'text':text_fixture,'mock':True,'notice':'模拟转写：没有录音或真实识别'}
class MockTTSProvider(TTSProvider):
    def synthesize(self, text, params):
        return {'mock':True,'audio_url':None,'params':asdict(params),'notice':'模拟语音：未生成音频'}

def emotion_params(label, language='zh-CN'):
    slow = label in {'sad','anxious','tired'}
    return VoiceParams(language=language,emotion=label,speed=.85 if slow else 1.0,
                       pitch=.95 if slow else 1.0, volume=.7 if slow else .8,pause=.5 if slow else .3)


class ProviderError(RuntimeError):
    """语音合成失败；绝不静默回退成其他声音。"""


def edge_params(params):
    """VoiceParams → edge-tts 的 rate/pitch 百分比字符串（沿用 EMOTION_VOICE 映射）。"""
    rate = f'{round((params.speed - 1) * 100):+d}%'
    pitch = f'{round((params.pitch - 1) * 100):+d}Hz'
    return rate, pitch


class EdgeTTSProvider(TTSProvider):
    """UNVERIFIED · 非官方接口：微软 Edge 朗读服务（edge-tts，LGPLv3，随时可能失效）。

    synthesize(text, params) → mp3 bytes；任何失败抛 ProviderError。
    """

    def __init__(self, voice='zh-CN-YunxiNeural'):
        self.voice = voice

    def synthesize(self, text, params):
        if not text.strip():
            raise ProviderError('合成文本为空')
        try:
            import edge_tts
        except ImportError as exc:
            raise ProviderError('edge-tts 未安装；源码运行请 pip install -r server/requirements.txt') from exc
        import asyncio

        rate, pitch = edge_params(params)
        async def _run():
            chunks = bytearray()
            communicate = edge_tts.Communicate(text, self.voice, rate=rate, pitch=pitch)
            async for chunk in communicate.stream():
                if chunk['type'] == 'audio':
                    chunks.extend(chunk['data'])
            return bytes(chunks)
        try:
            data = asyncio.run(_run())
        except Exception as exc:
            raise ProviderError(f'edge-tts 合成失败：{type(exc).__name__}') from exc
        if not data:
            raise ProviderError('edge-tts 返回空音频')
        return data
