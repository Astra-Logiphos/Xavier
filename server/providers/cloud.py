import json
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import URLError
from .base import LLMProvider, LLMResult
from ..model_config import read_model_config

class NoCredentialRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        return None

def urlopen(request, timeout):
    return build_opener(NoCredentialRedirect()).open(request, timeout=timeout)

class CloudProvider(LLMProvider):
    name = ''
    def __init__(self, config=None):
        self.model_config = config
    def complete(self, messages):
        config = self.model_config or read_model_config(self.name)
        body = json.dumps({'model': config.model, 'messages':messages, 'max_tokens':768, 'stream':False}).encode()
        request = Request(config.endpoint, data=body, headers={'Authorization':'Bearer '+config.api_key,'Content-Type':'application/json'})
        try:
            with urlopen(request, timeout=30) as response:
                raw = response.read(1024*1024+1)
                if len(raw)>1024*1024: raise ValueError('模型响应过大')
                answer = json.loads(raw)['choices'][0]['message']['content']
                if not isinstance(answer,str): raise ValueError('模型响应格式不支持')
                return LLMResult(answer, self.name, 'cloud')
        except (URLError, KeyError, IndexError, json.JSONDecodeError):
            raise ValueError('模型调用失败，请检查服务端配置与配额；错误正文已隐藏') from None

class DeepSeekProvider(CloudProvider):
    name = 'deepseek'

class ZhipuProvider(CloudProvider):
    name = 'zhipu'
