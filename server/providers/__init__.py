from .base import LLMProvider
from ..model_config import PROVIDERS, read_model_config
from .cloud import DeepSeekProvider, ZhipuProvider, SiliconFlowProvider, VolcengineProvider, DashscopeProvider
from .mock import MockProvider
from .ollama import OllamaProvider

def provider_for(config):
    mapping = {'mock':MockProvider, 'deepseek':DeepSeekProvider, 'zhipu':ZhipuProvider, 'ollama':OllamaProvider, 'siliconflow':SiliconFlowProvider, 'volcengine':VolcengineProvider, 'dashscope':DashscopeProvider}
    if config.provider not in mapping: raise ValueError('不支持的模型供应商')
    if config.provider == 'ollama' and not config.ollama_enabled: raise ValueError('Ollama 默认关闭')
    if config.provider in PROVIDERS:
        return mapping[config.provider](read_model_config(config.provider))
    return mapping[config.provider]()
