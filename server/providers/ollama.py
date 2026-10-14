from .base import LLMProvider
class OllamaProvider(LLMProvider):
    def complete(self, messages):
        raise ValueError('Ollama 仅预留本地 127.0.0.1 接口，尚未接入；当前不会发起请求')
