import json
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import URLError, HTTPError
from .base import LLMProvider, LLMResult
from ..model_config import read_model_config, catalog

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
        body = json.dumps({'model': config.model, 'messages':messages, 'max_tokens':getattr(self,'max_tokens',768), 'stream':False}).encode()
        request = Request(config.endpoint, data=body, headers={'Authorization':'Bearer '+config.api_key,'Content-Type':'application/json'})
        try:
            with urlopen(request, timeout=30) as response:
                raw = response.read(1024*1024+1)
                if len(raw)>1024*1024: raise ValueError('模型响应过大')
                payload = json.loads(raw)
                answer = payload['choices'][0]['message']['content']
                if not isinstance(answer,str): raise ValueError('模型响应格式不支持')
                return LLMResult(answer, self.name, 'cloud', payload.get('usage'))
        except HTTPError as exc:
            messages = {401:'API Key无效或无权限',402:'余额或额度不足',404:'模型未开通或接口地址有误',429:'请求频率或额度达到限制'}
            detail = messages.get(exc.code,'模型服务请求失败')
            if exc.code==404 and self.name=='volcengine':
                detail += '；需在控制台开通模型并检查接入点ID'
            raise ProviderError(catalog()[self.name]['label']+'：'+detail+'（'+str(exc.code)+'）', exc.code) from None
        except (URLError, TimeoutError, ConnectionError):
            raise ProviderError(catalog()[self.name]['label']+'：网络不通，请检查本机网络与接口地址',503) from None
        except (KeyError, IndexError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
            raise ValueError('模型调用失败，请检查服务端配置与配额；错误正文已隐藏') from None

class DeepSeekProvider(CloudProvider):
    name = 'deepseek'

class ZhipuProvider(CloudProvider):
    name = 'zhipu'

class ProviderError(ValueError):
    def __init__(self,message,status=400):
        self.status = status
        super().__init__(message)

class SiliconFlowProvider(CloudProvider):
    name = 'siliconflow'

class VolcengineProvider(CloudProvider):
    name = 'volcengine'

class DashscopeProvider(CloudProvider):
    name = 'dashscope'
