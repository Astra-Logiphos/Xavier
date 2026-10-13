from .base import LLMProvider, LLMResult
class MockProvider(LLMProvider):
    def complete(self, messages):
        question = messages[-1]['content']
        if any(x in question for x in ['难过','累','生气','焦虑']):
            reply = '先缓一缓。我在这里。愿意的话，我们可以慢慢整理眼前的事。'
        else:
            reply = '我在，慢慢说。现在是免费规则模式，还没有启用云端模型；我能陪你做记录、打卡和回顾。'
        return LLMResult(reply, 'mock', 'free_rules')
