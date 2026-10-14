from dataclasses import dataclass, field
import json
import os
from pathlib import Path
from urllib.parse import urlsplit
from .model_environment import REFERENCES, ENV_LOCK, load_environment

PROVIDERS = REFERENCES

def catalog():
    return json.loads((Path(__file__).resolve().parents[1]/'config/model_providers.json').read_text(encoding='utf8'))

@dataclass(frozen=True)
class ModelConfig:
    provider: str
    base_url: str
    model: str
    key_reference: str
    api_key: str = field(repr=False)

    @property
    def endpoint(self):
        return self.base_url.rstrip('/') + '/chat/completions'

def active_provider():
    load_environment()
    return os.getenv('ACTIVE_PROVIDER','mock').strip()

def validate_model_config(name,base,model,key):
    if name not in PROVIDERS:
        raise ValueError('不支持的模型供应商配置')
    if not base or not model or not key:
        raise ValueError('服务端未配置模型地址、名称或 API Key；可切回 mock 免费模式')
    try:
        parsed = urlsplit(base)
        valid = parsed.scheme=='https' and bool(parsed.hostname) and not parsed.username and not parsed.password and not parsed.query and not parsed.fragment
        parsed.port
    except ValueError:
        valid = False
    if not valid or len(base)>2048:
        raise ValueError('模型地址无效：请设置不含凭据、查询参数的 HTTPS base_url')
    if len(model)>200 or len(key)>8192 or '\r' in key or '\n' in key:
        raise ValueError('模型名称或Key格式无效')
    return ModelConfig(name,base.rstrip('/'),model,PROVIDERS[name][2],key)

def read_model_config(provider=None):
    load_environment()
    with ENV_LOCK:
        name = provider or active_provider()
        if name not in PROVIDERS:
            raise ValueError('不支持的模型供应商配置')
        return validate_model_config(name,*(os.getenv(ref,'').strip() for ref in PROVIDERS[name]))

def free_model(provider):
    refs = PROVIDERS.get(provider)
    if not refs:
        return False
    with ENV_LOCK:
        data = catalog()[provider]
        return os.getenv(refs[0],'').strip().rstrip('/')==data['base_url'].rstrip('/') and os.getenv(refs[1],'').strip() in data['free_models']

def free_config(config):
    data = catalog()[config.provider]
    return config.base_url.rstrip('/')==data['base_url'].rstrip('/') and config.model in data['free_models']

def model_status(provider):
    refs = PROVIDERS.get(provider)
    with ENV_LOCK:
        return {'model':os.getenv(refs[1],'').strip() or None} if refs else {'model':None}
