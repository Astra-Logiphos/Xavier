from abc import ABC, abstractmethod
from urllib.parse import urlparse

KEYWORDS = ['沈星回','沈星回 性格','沈星回 语气','沈星回 剧情','沈星回 细节','沈星回 保护欲','沈星回 口是心非','沈星回 互动']

class SourceConnector(ABC):
    @abstractmethod
    def capabilities(self): ...
    def search(self, keywords):
        raise ValueError('外部连接器未授权或未验证；请使用手动导入')

class XiaohongshuConnector(SourceConnector):
    def capabilities(self): return {'platform':'xiaohongshu','verified':False,'automatic_search':False,'notice':'需正式授权接口，不模拟登录'}
class BilibiliConnector(SourceConnector):
    def capabilities(self): return {'platform':'bilibili','verified':False,'automatic_search':False,'notice':'需允许的官方接口或公开文字'}
class PublicWebConnector(SourceConnector):
    def capabilities(self): return {'platform':'public_web','verified':False,'automatic_search':False,'notice':'不抓取任意 URL，防 SSRF；只保存链接'}
class ManualImportConnector(SourceConnector):
    def capabilities(self): return {'platform':'manual','verified':True,'automatic_search':False,'manual_import':True}
    def search(self, keywords): return []

def validate_url(url):
    if not url: return ''
    parsed = urlparse(url)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError('来源链接必须是无凭据的 HTTPS URL')
    return url

def connectors(): return [c().capabilities() for c in [XiaohongshuConnector,BilibiliConnector,PublicWebConnector,ManualImportConnector]]
