"""Evidence-based keyword retrieval; never returns unapproved/canon records."""
import re
from .policy import MEMORY_KINDS, retrievable

def tokens(text):
    words=set(re.findall(r'[A-Za-z0-9_]{2,}',text.lower()))
    for segment in re.findall(r'[\u4e00-\u9fff]+',text):
        words.update(segment[i:i+2] for i in range(len(segment)-1))
    return words-{'记得','喜欢','什么','我们','上次','可以','今天','我的','你的','一下','知道'}

class MemoryRetriever:
    def __init__(self,store): self.store=store
    def retrieve(self,query,limit=8):
        q=tokens(query); ranked=[]
        recall=any(w in query for w in ['你记得','还记得','我喜欢什么','我的偏好'])
        for row in self.store.all():
            if row['kind'] not in MEMORY_KINDS or not retrievable(row): continue
            text=row.get('content',row.get('topic',''))
            score=len(q & tokens(text))
            if recall and row['kind'] in {'profile_memory','relationship_memory','user_preference_memory'}: score+=1
            if score: ranked.append((score,row['updated_at'],row))
        ranked.sort(key=lambda item:(item[0],item[1]),reverse=True)
        return [row for _,_,row in ranked[:limit]]
