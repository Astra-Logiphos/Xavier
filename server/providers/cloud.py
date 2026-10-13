import json
import os
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import URLError
from .base import LLMProvider, LLMResult

class NoCredentialRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        return None

def urlopen(request, timeout):
    return build_opener(NoCredentialRedirect()).open(request, timeout=timeout)

class CloudProvider(LLMProvider):
    name = ''
    endpoint = ''
    def complete(self, messages):
        prefix = self.name.upper()
        key = os.getenv(prefix + '_API_KEY', '')
        model = os.getenv(prefix + '_MODEL', '')
        if not key or not model: raise ValueError('服务端未配置模型名称或 API Key；可切回 mock 免费模式')
        body = json.dumps({'model': model, 'messages':messages, 'max_tokens':768, 'stream':False}).encode()
        request = Request(self.endpoint, data=body, headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
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
    endpoint = 'https://api.deepseek.com/chat/completions'

class ZhipuProvider(CloudProvider):
    name = 'zhipu'
    endpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions'
