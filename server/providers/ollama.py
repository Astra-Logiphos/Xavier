from .base import LLMProvider
class OllamaProvider(LLMProvider):
    def complete(self, messages):
        raise ValueError('Ollama 仅预留云端接口，未接入；不会访问用户本地电脑')
