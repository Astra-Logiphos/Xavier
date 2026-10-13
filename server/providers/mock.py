from .base import LLMProvider, LLMResult
class MockProvider(LLMProvider):
    def complete(self, messages):
        question = messages[-1]['content']
        if any(x in question for x in ['难过','累','生气','焦虑']):
            reply = '先缓一缓。我在这里。愿意的话，我们可以慢慢整理眼前的事。'
        else:
            reply = '我在，慢慢说。今天想从哪里开始？'
        return LLMResult(reply, 'mock', 'free_rules')
