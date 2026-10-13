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
