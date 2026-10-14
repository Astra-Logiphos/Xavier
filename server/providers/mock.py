from .base import LLMProvider, LLMResult
from ..persona.core import core_card

class MockProvider(LLMProvider):
    def complete(self,messages):
        question=messages[-1]['content']
        lines=core_card()['static']
        reply=next((entry['reply'] for entry in lines['identity'] if any(key in question for key in entry['keys'])),None)
        if reply is None and any(word in question for word in ('今天几号','今天是几号','今天日期')) and hasattr(self,'now'):
            now=self.now()
            reply=lines['today_reply'].format(year=now.year,month=now.month,day=now.day)
        if reply is None:
            reply=lines['comfort'] if any(word in question for word in ('难过','累','生气','焦虑','烦')) else lines['default_reply']
        return LLMResult(reply,'mock','free_rules')
