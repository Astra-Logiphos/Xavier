"""Server environment is the sole source of provider endpoints, models and keys."""
from dataclasses import dataclass, field
import os
from urllib.parse import urlsplit

# Registry contains environment variable references, never endpoints or credentials.
PROVIDERS = {
    'zhipu': ('ZHIPU_BASE_URL', 'ZHIPU_MODEL', 'ZHIPU_API_KEY'),
    'deepseek': ('DEEPSEEK_BASE_URL', 'DEEPSEEK_MODEL', 'DEEPSEEK_API_KEY'),
}

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
    return os.getenv('ACTIVE_PROVIDER', 'mock').strip()

def read_model_config(provider=None):
    name = provider or active_provider()
    if name not in PROVIDERS:
        raise ValueError('不支持的模型供应商配置')
    base_ref, model_ref, key_ref = PROVIDERS[name]
    base, model, key = (os.getenv(ref, '').strip() for ref in (base_ref, model_ref, key_ref))
    if not base or not model or not key:
        raise ValueError('服务端未配置模型地址、名称或 API Key；可切回 mock 免费模式')
    try:
        parsed = urlsplit(base)
        valid = parsed.scheme == 'https' and bool(parsed.hostname) and not parsed.username and not parsed.password and not parsed.query and not parsed.fragment
        parsed.port
    except ValueError:
        valid = False
    if not valid:
        raise ValueError('模型地址无效：请设置不含凭据、查询参数的 HTTPS base_url')
    return ModelConfig(name, base.rstrip('/'), model, key_ref, key)

def model_status(provider):
    """Public metadata only; never return key contents or credential references."""
    refs=PROVIDERS.get(provider)
    return {'model':os.getenv(refs[1], '').strip() or None} if refs else {'model':None}
