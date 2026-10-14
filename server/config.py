from dataclasses import dataclass
import os
from .model_config import active_provider
from .memory.context import history_settings

def flag(name, default=False):
    return os.getenv(name, str(default)).lower() == 'true'

@dataclass(frozen=True)
class Config:
    database: str = 'runtime/xinghui.db'
    token: str = ''
    timezone: str = 'Asia/Shanghai'
    provider: str = 'mock'
    api_enabled: bool = False
    require_confirmation: bool = False
    allow_paid: bool = False
    ollama_enabled: bool = False
    search_enabled: bool = False
    voice_enabled: bool = False
    emotion_enabled: bool = True
    max_daily_calls: int = 20

    history_rounds: int = 10
    history_character_budget: int = 6000

    @classmethod
    def env(cls):
        rounds, budget = history_settings()
        return cls(history_rounds=rounds, history_character_budget=budget, database=os.getenv('DATABASE_PATH', 'runtime/xinghui.db'),
                   token=os.getenv('AUTH_TOKEN', ''), timezone=os.getenv('USER_TIMEZONE', 'Asia/Shanghai'),
                   provider=active_provider(), api_enabled=flag('API_ENABLED'),
                   require_confirmation=flag('REQUIRE_API_CONFIRMATION', False), allow_paid=flag('ALLOW_PAID_API'),
                   ollama_enabled=flag('OLLAMA_ENABLED'), search_enabled=flag('EXTERNAL_SEARCH_ENABLED'),
                   voice_enabled=flag('VOICE_ENABLED'), emotion_enabled=flag('EMOTION_ENABLED', True),
                   max_daily_calls=max(0, int(os.getenv('MAX_DAILY_MODEL_CALLS', '20'))))
