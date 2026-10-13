from dataclasses import dataclass
import os

def flag(name, default=False):
    return os.getenv(name, str(default)).lower() == 'true'

@dataclass(frozen=True)
class Config:
    database: str = 'runtime/xinghui.db'
    token: str = ''
    timezone: str = 'Asia/Shanghai'
    provider: str = 'mock'
    api_enabled: bool = False
    require_confirmation: bool = True
    allow_paid: bool = False
    ollama_enabled: bool = False
    search_enabled: bool = False
    voice_enabled: bool = False
    emotion_enabled: bool = True
    max_daily_calls: int = 20

    @classmethod
    def env(cls):
        return cls(database=os.getenv('DATABASE_PATH', 'runtime/xinghui.db'),
                   token=os.getenv('AUTH_TOKEN', ''), timezone=os.getenv('USER_TIMEZONE', 'Asia/Shanghai'),
                   provider=os.getenv('ACTIVE_PROVIDER', 'mock'), api_enabled=flag('API_ENABLED'),
                   require_confirmation=flag('REQUIRE_API_CONFIRMATION', True), allow_paid=flag('ALLOW_PAID_API'),
                   ollama_enabled=flag('OLLAMA_ENABLED'), search_enabled=flag('EXTERNAL_SEARCH_ENABLED'),
                   voice_enabled=flag('VOICE_ENABLED'), emotion_enabled=flag('EMOTION_ENABLED', True),
                   max_daily_calls=max(0, int(os.getenv('MAX_DAILY_MODEL_CALLS', '20'))))
