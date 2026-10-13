from .base import LLMProvider
from .cloud import DeepSeekProvider, ZhipuProvider
from .mock import MockProvider
from .ollama import OllamaProvider

def provider_for(config):
    mapping = {'mock':MockProvider, 'deepseek':DeepSeekProvider, 'zhipu':ZhipuProvider, 'ollama':OllamaProvider}
    if config.provider not in mapping: raise ValueError('不支持的模型供应商')
    if config.provider == 'ollama' and not config.ollama_enabled: raise ValueError('Ollama 默认关闭')
    return mapping[config.provider]()
